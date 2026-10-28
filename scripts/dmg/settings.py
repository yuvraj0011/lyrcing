# dmgbuild settings for the Lyrcing installer window.
#   dmgbuild -s scripts/dmg/settings.py -D app=dist/Lyrcing.app "Lyrcing" dist/Lyrcing.dmg
import os

app = defines.get("app", "dist/Lyrcing.app")          # noqa: F821  (`defines` is provided by dmgbuild)
here = defines.get("here", "scripts/dmg")                # noqa: F821  (run from the repo root)
name = os.path.basename(app)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")   # volume icon
background = os.path.join(here, "background.tiff")

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
window_rect = ((200, 140), (660, 400))
icon_size = 120
text_size = 13
arrange_by = None
icon_locations = {name: (170, 200), "Applications": (490, 200)}
