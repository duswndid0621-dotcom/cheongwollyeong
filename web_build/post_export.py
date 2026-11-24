"""웹 내보내기 뒤처리: 큰 게임 데이터(index.pck)를 40MB 조각으로 나누고,
페이지가 조각을 이어 붙여 읽게 한다 (GitHub Pages 는 100MB 넘는 파일을 못 올림)."""
import os, sys, re
out = sys.argv[1]
pck = os.path.join(out, "index.pck")
size = os.path.getsize(pck)
CH = 40 * 1024 * 1024
parts = []
with open(pck, "rb") as f:
    k = 0
    while True:
        b = f.read(CH)
        if not b: break
        name = f"index.pck.{k:02d}"
        open(os.path.join(out, name), "wb").write(b); parts.append(name); k += 1
os.remove(pck)
loader = """<script>
(() => {
  const PARTS = %s, SIZE = %d;
  const realFetch = window.fetch.bind(window);
  function joined() {
    let i = 0, reader = null;
    const body = new ReadableStream({ async pull(ctrl) {
      try {
        for (;;) {
          if (!reader) {
            if (i >= PARTS.length) { ctrl.close(); return; }
            const r = await realFetch(PARTS[i++]);
            if (!r.ok) throw new Error("게임 파일을 받지 못했습니다 (" + r.status + ")");
            reader = r.body.getReader();
          }
          const { done, value } = await reader.read();
          if (done) { reader = null; continue; }
          ctrl.enqueue(value); return;
        }
      } catch (e) { ctrl.error(e); }
    }});
    return new Response(body, { headers: { "Content-Type": "application/octet-stream", "Content-Length": String(SIZE) } });
  }
  window.fetch = (input, init) => {
    const url = typeof input === "string" ? input : (input && input.url) || "";
    if (/index\\.pck(\\?|$)/.test(url)) return Promise.resolve(joined());
    return realFetch(input, init);
  };
})();
</script>
""" % (str(parts).replace("'", '"'), size)
p = os.path.join(out, "index.html")
html = open(p, encoding="utf-8").read()
html = html.replace("<title>", "<title>", 1)
i = html.index('<script src="index.js">')
html = html[:i] + loader + html[i:]
open(p, "w", encoding="utf-8").write(html)
open(os.path.join(out, ".nojekyll"), "w").close()
print("조각", parts, "전체", size)
