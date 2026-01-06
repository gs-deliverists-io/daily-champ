# Screenshots

Place your app screenshots here.

## Expected Files

- `day-win.png` - Daily view showing a winning day
- `day-loss.png` - Daily view showing a losing day
- `add-task.png` - Add task bottom sheet
- `calendar.png` - Calendar view with wins/losses
- `stats.png` - Statistics dashboard
- `settings.png` - Settings page with Nextcloud sync

## Optimization

To optimize PNG files for GitHub, you can use one of these tools:

### Option 1: Using ImageOptim (macOS)
1. Download [ImageOptim](https://imageoptim.com/mac)
2. Drag all PNG files into ImageOptim
3. It will compress them without quality loss

### Option 2: Using pngquant (CLI)
```bash
# Install
brew install pngquant

# Optimize all PNG files
cd screenshots
for file in *.png; do
  pngquant --quality=65-80 --ext .png --force "$file"
done
```

### Option 3: Using TinyPNG Web
1. Go to https://tinypng.com/
2. Upload your PNG files
3. Download optimized versions

## Recommended Dimensions

For mobile app screenshots:
- Width: 400-500px (for README display)
- Original device screenshots will be downscaled with HTML/CSS

The README uses `width="250"` in the HTML, so any size above 500px works well.
