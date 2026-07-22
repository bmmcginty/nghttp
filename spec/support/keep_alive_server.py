#!/usr/bin/env python3
import argparse
import json
import socket
import threading
import time


def read_headers(conn):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(4096)
        if not chunk:
            return None, {}
        data += chunk
    header_text = data.split(b"\r\n\r\n", 1)[0].decode("iso-8859-1")
    lines = header_text.split("\r\n")
    headers = {}
    for line in lines[1:]:
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.lower()] = value.strip()
    return lines[0], headers


def handle_client(conn, connection_id):
    request_count = 0
    started = time.time()
    try:
        while True:
            request_line, headers = read_headers(conn)
            if request_line is None:
                return

            request_count += 1
            close = headers.get("connection", "").lower() == "close"
            path = request_line.split(" ")[1] if " " in request_line else "/"
            if path == "/conn":
                status = "200 OK"
                body = json.dumps(
                    {
                        "connection": str(connection_id),
                        "connection_requests": str(request_count),
                        "connection_time": str(time.time() - started),
                    },
                    separators=(",", ":"),
                ).encode("utf-8")
                content_type = "application/json"
            else:
                status = "404 Not Found"
                body = b"not found"
                content_type = "text/plain"

            response_headers = [
                f"HTTP/1.1 {status}",
                f"Content-Length: {len(body)}",
                f"Content-Type: {content_type}",
                f"Connection: {'close' if close else 'keep-alive'}",
                "",
                "",
            ]
            conn.sendall("\r\n".join(response_headers).encode("ascii") + body)
            if close:
                return
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((args.host, args.port))
    server.listen()

    connection_id = 0
    while True:
        conn, _addr = server.accept()
        connection_id += 1
        thread = threading.Thread(target=handle_client, args=(conn, connection_id), daemon=True)
        thread.start()


if __name__ == "__main__":
    main()
