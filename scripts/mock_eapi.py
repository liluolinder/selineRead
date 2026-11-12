"""本地 eapi 模拟服务器（仅用于验证竞态/分页，不依赖外网站点）。

端点：
  POST /eapi/book/search         → 3 页、每页 20 本的假搜索结果
  GET  /eapi/book/111/<hash>     → 故意延迟 4s 返回书名 MOCK-A（模拟"慢的上一本"）
  GET  /eapi/book/222/<hash>     → 立即返回书名 MOCK-B（模拟"快的下一本"）
  其它                            → {"success":1}
"""

import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

PORT = 8099
DELAY_BOOK_ID = 111
DELAY_SECONDS = 4.0
PAGE_SIZE = 20
TOTAL_PAGES = 3


def book_dict(book_id, title, author="MOCK 作者", page_tag=""):
    return {
        "id": book_id,
        "contentType": "book",
        "title": title,
        "author": author,
        "year": 2020,
        "language": "chinese",
        "pages": 100,
        "publisher": "MOCK 出版社",
        "series": "",
        "cover": "",
        "extension": "epub",
        "filesize": 1234567,
        "filesizeString": "1.2 MB",
        "description": f"这是 {title} 的模拟简介。{page_tag}",
        "hash": "mockhash",
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        print("MOCK " + (fmt % args), flush=True)

    def _send(self, payload):
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self):
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length).decode("utf-8", "replace") if length else ""
        form = {k: v[0] for k, v in parse_qs(body).items()}

        if path.endswith("/book/search"):
            page = int(form.get("page", "1") or "1")
            books = []
            for i in range(PAGE_SIZE):
                idx = (page - 1) * PAGE_SIZE + i + 1
                books.append(book_dict(5000 + idx, f"MOCK 第{page}页 书{idx}",
                                       page_tag=f"page={page}"))
            self._send({
                "success": 1,
                "books": books,
                "pagination": {
                    "limit": PAGE_SIZE,
                    "current": page,
                    "total_items": PAGE_SIZE * TOTAL_PAGES,
                    "total_pages": TOTAL_PAGES,
                },
            })
            return

        self._send({"success": 1})

    def do_GET(self):
        path = urlparse(self.path).path
        parts = [p for p in path.split("/") if p]
        # /eapi/book/<id>/<hash>
        if len(parts) >= 3 and parts[1] == "book":
            try:
                book_id = int(parts[2])
            except ValueError:
                self._send({"success": 1})
                return
            if book_id == DELAY_BOOK_ID:
                time.sleep(DELAY_SECONDS)
                self._send({"success": 1,
                            "book": book_dict(book_id, "MOCK-A（慢）")})
                return
            self._send({"success": 1,
                        "book": book_dict(book_id, f"MOCK-B（快 id={book_id}）",
                                          author="MOCK 作者B")})
            return

        self._send({"success": 1})


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"mock eapi listening on http://127.0.0.1:{PORT}", flush=True)
    server.serve_forever()
