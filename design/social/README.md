# Social preview

The image GitHub shows when the repository is linked (1280 x 640 px).

| Path | What |
| --- | --- |
| `social-preview.svg` | Source: the icon master from `design/icon/ShortcutLens.svg`, the tagline and an overlay screenshot. |
| `overlay-crop.png` | The screenshot: `docs/images/overlay-dark.png` cropped to 1400 x 1300 px from the top left and scaled to 700 px wide. rsvg-convert only loads images next to the SVG. |
| `social-preview.png` | Rendered image, uploaded in Settings > General > Social preview. |

GitHub has no API for the social preview; after a change, the PNG is
uploaded again in Settings > General. Render it with:

```sh
rsvg-convert -w 1280 -h 640 design/social/social-preview.svg -o design/social/social-preview.png
```

Keep the icon in step with `design/icon/ShortcutLens.svg`. Recreate the crop when the overlay screenshot changes:

```sh
ffmpeg -i docs/images/overlay-dark.png -vf "crop=1400:1300:0:0,scale=700:-1:flags=lanczos" design/social/overlay-crop.png
```
