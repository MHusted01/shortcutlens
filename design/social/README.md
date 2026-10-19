# Social preview

The image GitHub shows when the repository is linked (1280 x 640 px).

| Path | What |
| --- | --- |
| `social-preview.svg` | Source: the icon master from `design/icon/ShortcutLens.svg` plus the tagline. |
| `social-preview.png` | Rendered image, uploaded in Settings > General > Social preview. |

GitHub has no API for the social preview, so upload the PNG by hand after
changing it. Render it with:

```sh
rsvg-convert -w 1280 -h 640 design/social/social-preview.svg -o design/social/social-preview.png
```

Keep the icon in step with `design/icon/ShortcutLens.svg`.
