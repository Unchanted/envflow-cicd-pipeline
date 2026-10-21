import sys,pathlib
from playwright.sync_api import sync_playwright
src=pathlib.Path(sys.argv[1]).resolve(); owner=sys.argv[2]; out=sys.argv[3]
tmp=src.with_name("_render.html"); tmp.write_text(src.read_text().replace("__GH_OWNER__",owner))
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
    pg=b.new_page(); pg.goto(tmp.as_uri()); pg.wait_for_load_state("networkidle")
    pg.pdf(path=out,format="A4",print_background=True,display_header_footer=True,
      header_template="<span></span>",
      footer_template='<div style="width:100%;font-size:8px;color:#6b7280;padding:0 20mm;display:flex;justify-content:space-between;font-family:Helvetica"><span>EnvFlow · Multi-Environment CI/CD Pipeline</span><span class="pageNumber"></span></div>',
      margin={"top":"20mm","bottom":"20mm","left":"0","right":"0"})
    b.close()
tmp.unlink()
