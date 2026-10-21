#!/usr/bin/env python3

import argparse
import os
import sys
import time
import unittest

HEALTH_TIMEOUT = 120  # seconds to wait for the container to become healthy

# Every path configuration that has to work. A path that is listed twice must
# not make the server panic, see https://github.com/satishweb/docker-doh/issues/40
#   name, primary path, additional paths, paths that have to answer
PATH_CASES = [
    ("primary equals additional", "/dns-query", "/dns-query", ["/dns-query"]),
    ("primary equals additional, legacy path", "/getnsrecord", "/getnsrecord", ["/getnsrecord"]),
    ("the same path twice in the additional paths", "/getnsrecord", "/getnsrecord,/getnsrecord", ["/getnsrecord"]),
    ("the primary path is listed again", "/x", "/x,/y,/x", ["/x", "/y"]),
    ("all paths are the same", "/a1", "/a1", ["/a1"]),
    ("the default paths", "/getnsrecord", "/dns-query", ["/getnsrecord", "/dns-query"]),
    ("the paths of the helm chart", "/dns-query", "/getnsrecord", ["/dns-query", "/getnsrecord"]),
    ("the example of the readme", "/dns-query", "", ["/dns-query"]),
    ("several distinct paths", "/p1", "/p2,/p3", ["/p1", "/p2", "/p3"]),
    ("empty additional paths", "/getnsrecord", "", ["/getnsrecord"]),
    ("empty primary path", "", "/dns-query", ["/dns-query"]),
    ("whitespace around the paths", " /getnsrecord ", " /dns-query ", ["/getnsrecord", "/dns-query"]),
    ("a trailing comma", "/getnsrecord", "/dns-query,", ["/getnsrecord", "/dns-query"]),
    ("a leading comma", "/getnsrecord", ",/dns-query", ["/getnsrecord", "/dns-query"]),
]


def install_dependencies():
    missing = []
    for module in ("requests", "docker"):
        try:
            __import__(module)
        except ImportError:
            missing.append(module)
    if missing:
        print(
            "ERROR: missing python module(s): {}. "
            "Install them with: pip install {}".format(", ".join(missing), " ".join(missing)),
            file=sys.stderr,
        )
        sys.exit(1)


def wait_for_container_health(container, timeout=HEALTH_TIMEOUT):
    print("Waiting for container to be healthy...")
    deadline = time.time() + timeout
    while True:
        container.reload()
        state = container.attrs.get("State", {})
        health = state.get("Health", {})
        status = health.get("Status")
        if status == "healthy":
            print("Container is healthy.")
            return
        if state.get("Status") in ("exited", "dead"):
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Container stopped before it became healthy (status={state.get('Status')}).\n{logs}"
            )
        if time.time() > deadline:
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Container did not become healthy within {timeout}s (last status={status}).\n{logs}"
            )
        time.sleep(1)


def wait_for_server(container, port, timeout=HEALTH_TIMEOUT):
    """Wait until the server answers a query, without waiting for the health
    status of the container which takes a minute because of the health check
    interval."""
    import requests

    print(f"Waiting for the server on port {port}...")
    deadline = time.time() + timeout
    while True:
        container.reload()
        state = container.attrs.get("State", {})
        if state.get("Status") in ("exited", "dead"):
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Container stopped before it answered (status={state.get('Status')}).\n{logs}"
            )
        try:
            response = requests.get(
                f"http://localhost:{port}/?name=healthcheck.example&type=A", timeout=5
            )
            # Any answer proves that the server is up, even a 404 for a path
            # that is not configured.
            if response.status_code:
                print("The server answers.")
                return
        except requests.exceptions.RequestException:
            pass
        if time.time() > deadline:
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"The server did not answer within {timeout}s.\n{logs}"
            )
        time.sleep(1)


def run_tests(image_name, port, upstream_dns, prefix, prefixes, timeout, tries, verbose):
    install_dependencies()

    import docker
    import requests

    class TestDockerHealthCheck(unittest.TestCase):
        def test_healthcheck(self):
            print("Running health check test...")
            # Health check URL constructed based on Dockerfile's health check command
            healthcheck_url = f"http://localhost:{port}{prefix}?name=google.com&type=A"

            # Send a GET request to the health check URL
            response = requests.get(healthcheck_url, timeout=30)

            # Assert that the response status code is 200 (OK)
            self.assertEqual(response.status_code, 200, f"Unexpected status code for {healthcheck_url}")

            # The upstream returns the Google JSON API format.
            payload = response.json()

            # Assert that the DNS query succeeded (RCODE 0 = NOERROR)
            self.assertEqual(payload.get("Status"), 0, f"DNS query failed: {payload}")

            # Assert that the question matches the requested name
            questions = payload.get("Question") or []
            self.assertTrue(questions, f"No question returned: {payload}")
            self.assertEqual(questions[0].get("name"), "google.com.")

            # Assert that an A record was returned
            answers = payload.get("Answer") or []
            self.assertTrue(answers, f"No answer returned: {payload}")
            self.assertEqual(answers[0].get("type"), 1, f"Expected an A record: {payload}")
            print("Health check test passed.")

        def test_additional_paths(self):
            """The resolve endpoint has to be served on every configured path."""
            for path in [p for p in prefixes.split(",") if p.strip()]:
                path = path.strip()
                print(f"Testing additional path {path}...")
                response = requests.get(
                    f"http://localhost:{port}{path}?name=google.com&type=A", timeout=30
                )
                self.assertEqual(response.status_code, 200, f"Unexpected status code for {path}")
                payload = response.json()
                self.assertEqual(payload.get("Status"), 0, f"DNS query failed on {path}: {payload}")
                self.assertTrue(payload.get("Answer"), f"No answer returned on {path}: {payload}")
            print("Additional path test passed.")

        def test_unknown_path(self):
            """A path that is not configured must not be served."""
            response = requests.get(
                f"http://localhost:{port}/this-path-does-not-exist?name=google.com", timeout=30
            )
            self.assertEqual(response.status_code, 404, "Unknown path should return 404")
            print("Unknown path test passed.")

    print(f"Starting Docker container using image '{image_name}' and port '{port}'...")
    client = docker.from_env()
    container = client.containers.run(
        image_name,
        detach=True,
        ports={f"{port}": f"{port}"},
        environment={
            "UPSTREAM_DNS_SERVER": upstream_dns,
            "DOH_HTTP_PREFIX": prefix,
            "DOH_HTTP_PREFIXES": prefixes,
            "DOH_SERVER_LISTEN": f":{port}",
            "DOH_SERVER_TIMEOUT": timeout,
            "DOH_SERVER_TRIES": tries,
            "DOH_SERVER_VERBOSE": verbose,
        },
    )

    try:
        wait_for_container_health(container)

        # Load test case into test suite
        suite = unittest.TestLoader().loadTestsFromTestCase(TestDockerHealthCheck)

        # Run the tests
        print("Running tests...")
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        if not result.wasSuccessful():
            sys.exit(1)
    finally:
        # Stop and remove the container after tests
        print("Stopping Docker container...")
        container.stop()
        container.remove()
        print("Docker container stopped and removed.")

    run_path_configuration_tests(client, image_name, upstream_dns, timeout, tries, verbose)
    run_tls_test(client, image_name, upstream_dns, timeout, tries, verbose)


def run_tls_test(client, image_name, upstream_dns, timeout, tries, verbose):
    """The server has to serve https when it is configured with a certificate
    and a key, and the health check has to use https as well."""
    import requests
    import shutil
    import subprocess
    import tempfile

    if shutil.which("openssl") is None:
        print("\nSkipping the TLS test, openssl is not available.")
        return

    # The certificates are created in the cache directory of the user. The
    # temporary directory of the operating system can not be mounted, it is
    # not shared with the docker daemon.
    cache_dir = os.path.join(os.path.expanduser("~"), ".cache")
    os.makedirs(cache_dir, exist_ok=True)
    cert_dir = os.path.realpath(tempfile.mkdtemp(prefix="doh-tls-", dir=cache_dir))
    cert = os.path.join(cert_dir, "server.crt")
    key = os.path.join(cert_dir, "server.key")
    # The server runs as the unprivileged user of the container, so the
    # certificate and the key have to be readable for it.
    os.chmod(cert_dir, 0o755)
    subprocess.run(
        [
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", key, "-out", cert, "-days", "1", "-subj", "/CN=doh.test",
        ],
        check=True,
        capture_output=True,
    )
    os.chmod(cert, 0o644)
    os.chmod(key, 0o644)

    port = 18150
    print("\nRunning the TLS test...")
    container = client.containers.run(
        image_name,
        detach=True,
        ports={f"{port}": f"{port}"},
        environment={
            "UPSTREAM_DNS_SERVER": upstream_dns,
            "DOH_HTTP_PREFIX": "/getnsrecord",
            "DOH_HTTP_PREFIXES": "/dns-query",
            "DOH_SERVER_LISTEN": f":{port}",
            "DOH_SERVER_TIMEOUT": timeout,
            "DOH_SERVER_TRIES": tries,
            "DOH_SERVER_VERBOSE": verbose,
            "DOH_SERVER_CERT": "/certs/server.crt",
            "DOH_SERVER_KEY": "/certs/server.key",
        },
        volumes={cert_dir: {"bind": "/certs", "mode": "ro"}},
    )
    try:
        wait_for_server(container, port)
        response = requests.get(
            f"https://localhost:{port}/getnsrecord?name=google.com&type=A",
            timeout=30,
            verify=False,
        )
        if response.status_code != 200 or response.json().get("Status") != 0:
            print(f"FAIL: the TLS test returned {response.status_code} {response.text[:120]}")
            sys.exit(1)
        # The health check has to use https as well.
        exit_code = container.exec_run("/docker-healthcheck").exit_code
        if exit_code != 0:
            print("FAIL: the health check did not pass with TLS enabled")
            sys.exit(1)
        print("TLS test passed.")
    finally:
        container.stop()
        container.remove()
        shutil.rmtree(cert_dir, ignore_errors=True)


def run_path_configuration_tests(client, image_name, upstream_dns, timeout, tries, verbose):
    """Every combination of the primary and the additional paths has to work.

    A path that is configured twice makes the upstream server panic, so the
    whole matrix is checked. See https://github.com/satishweb/docker-doh/issues/40
    """
    import requests

    class TestPathConfigurations(unittest.TestCase):
        def test_path_configurations(self):
            base_port = 18100
            for index, (name, primary, additional, expected) in enumerate(PATH_CASES):
                with self.subTest(configuration=name):
                    case_port = base_port + index
                    container = client.containers.run(
                        image_name,
                        detach=True,
                        ports={f"{case_port}": f"{case_port}"},
                        environment={
                            "UPSTREAM_DNS_SERVER": upstream_dns,
                            "DOH_HTTP_PREFIX": primary,
                            "DOH_HTTP_PREFIXES": additional,
                            "DOH_SERVER_LISTEN": f":{case_port}",
                            "DOH_SERVER_TIMEOUT": timeout,
                            "DOH_SERVER_TRIES": tries,
                            "DOH_SERVER_VERBOSE": verbose,
                        },
                    )
                    try:
                        wait_for_server(container, case_port)
                        for path in expected:
                            response = requests.get(
                                f"http://localhost:{case_port}{path}?name=google.com&type=A",
                                timeout=30,
                            )
                            self.assertEqual(
                                response.status_code, 200, f"{path} did not answer: {name}"
                            )
                            self.assertEqual(
                                response.json().get("Status"), 0, f"{path} failed: {name}"
                            )
                        response = requests.get(
                            f"http://localhost:{case_port}/not-a-configured-path?name=google.com",
                            timeout=30,
                        )
                        self.assertEqual(
                            response.status_code, 404, f"unknown path was served: {name}"
                        )
                        # The health check has to succeed for the container as
                        # well. The script is run directly, waiting for the
                        # health status of the container would take a minute
                        # for every case.
                        exit_code = container.exec_run("/docker-healthcheck").exit_code
                        self.assertEqual(
                            exit_code, 0, f"the health check failed: {name}"
                        )
                    finally:
                        container.stop()
                        container.remove()

    print("\nRunning path configuration tests...")
    suite = unittest.TestLoader().loadTestsFromTestCase(TestPathConfigurations)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    # Argument parser for overriding default values
    parser = argparse.ArgumentParser(description="Run tests for Docker container with health check.")
    parser.add_argument("--image", type=str, default="satishweb/doh-server-test", help="Docker image name (default: satishweb/doh-server)")
    parser.add_argument("--port", type=str, default="8053", help="Port number for the Docker container (default: 8053)")
    parser.add_argument("--upstream_dns", type=str, default="udp:208.67.222.222:53", help="Upstream DNS server (default: udp:208.67.222.222:53)")
    parser.add_argument("--prefix", type=str, default="/getnsrecord", help="Primary HTTP prefix (default: /getnsrecord)")
    parser.add_argument("--prefixes", type=str, default="/dns-query", help="Additional HTTP prefixes, comma separated (default: /dns-query)")
    parser.add_argument("--timeout", type=str, default="10", help="Timeout for DNS queries (default: 10)")
    parser.add_argument("--tries", type=str, default="3", help="Number of retries for failed DNS queries (default: 3)")
    parser.add_argument("--verbose", type=str, default="false", help="Verbose mode for the DoH server (default: false)")
    args = parser.parse_args()

    run_tests(args.image, args.port, args.upstream_dns, args.prefix, args.prefixes, args.timeout, args.tries, args.verbose)
