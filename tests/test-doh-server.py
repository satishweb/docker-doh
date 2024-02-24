#!/usr/bin/env python3

import time
import unittest
import requests
import argparse
import os

def install_dependencies():
    # Check if Pipfile.lock exists
    if not os.path.exists("Pipfile.lock"):
        print("Installing dependencies...")
        os.system("pipenv install")
        print("Dependencies installed.")

def run_tests(image_name, port, upstream_dns, prefix, timeout, tries, verbose):
    install_dependencies()  # Install dependencies if not already installed

    import docker

    class TestDockerHealthCheck(unittest.TestCase):
        def test_healthcheck(self):
            print("Running health check test...")
            # Health check URL constructed based on Dockerfile's health check command
            healthcheck_url = f"http://localhost:{port}{prefix}?name=google.com&type=A"

            # Send a GET request to the health check URL
            response = requests.get(healthcheck_url)

            # Assert that the response status code is 200 (OK)
            self.assertEqual(response.status_code, 200)

            # Assert that the response body contains the IP address of google.com
            self.assertIn("google.com", response.text)
            self.assertIn("A", response.text)  # Asserting the record type is A
            print("Health check test passed.")

    def wait_for_container_health(container):
        print("Waiting for container to be healthy...")
        while True:
            container.reload()
            health = container.attrs.get("State", {}).get("Health", {})
            status = health.get("Status")
            if status == "healthy":
                break
            time.sleep(1)
        print("Container is healthy.")

    print(f"Starting Docker container using image '{image_name}' and port '{port}'...")
    client = docker.from_env()
    container = client.containers.run(image_name, detach=True, ports={f"{port}": f"{port}"}, environment={
        "UPSTREAM_DNS_SERVER": upstream_dns,
        "DOH_HTTP_PREFIX": prefix,
        "DOH_SERVER_LISTEN": f":{port}",
        "DOH_SERVER_TIMEOUT": timeout,
        "DOH_SERVER_TRIES": tries,
        "DOH_SERVER_VERBOSE": verbose
    })

    wait_for_container_health(container)

    # Load test case into test suite
    suite = unittest.TestLoader().loadTestsFromTestCase(TestDockerHealthCheck)

    # Run the tests
    print("Running tests...")
    unittest.TextTestRunner(verbosity=2).run(suite)

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
    parser.add_argument("--prefix", type=str, default="/getnsrecord", help="HTTP prefix (default: /getnsrecord)")
    parser.add_argument("--timeout", type=str, default="10", help="Timeout for DNS queries (default: 10)")
    parser.add_argument("--tries", type=str, default="3", help="Number of retries for failed DNS queries (default: 3)")
    parser.add_argument("--verbose", type=str, default="false", help="Verbose mode for the DoH server (default: false)")
    args = parser.parse_args()

    run_tests(args.image, args.port, args.upstream_dns, args.prefix, args.timeout, args.tries, args.verbose)
