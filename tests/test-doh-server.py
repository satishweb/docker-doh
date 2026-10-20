#!/usr/bin/env python3

import argparse
import json
import os
import sys
import time
import unittest

HEALTH_TIMEOUT = 120  # seconds to wait for the container to become healthy


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
