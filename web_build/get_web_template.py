"""고도트 내보내기 템플릿 묶음(1GB 넘음)에서 웹 템플릿만 골라 받는다 (HTTP Range)."""
import io, sys, zipfile, urllib.request, os
ver, dst = sys.argv[1], sys.argv[2]
URL = f"https://github.com/godotengine/godot-builds/releases/download/{ver}-stable/Godot_v{ver}-stable_export_templates.tpz"
head = urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"))
real, size = head.geturl(), int(head.headers["Content-Length"])
class R(io.RawIOBase):
    pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, o, w=0):
        self.pos = o if w == 0 else (self.pos + o if w == 1 else size + o); return self.pos
    def readinto(self, b):
        n = min(len(b), size - self.pos)
        if n <= 0: return 0
        req = urllib.request.Request(real, headers={"Range": f"bytes={self.pos}-{self.pos + n - 1}"})
        d = urllib.request.urlopen(req).read()
        b[:len(d)] = d; self.pos += len(d); return len(d)
z = zipfile.ZipFile(io.BufferedReader(R(), buffer_size=1 << 20))
for n in z.namelist():
    if n.endswith("web_nothreads_release.zip") or n.endswith("web_release.zip"):
        open(os.path.join(dst, os.path.basename(n)), "wb").write(z.read(n)); print("받음", n)
