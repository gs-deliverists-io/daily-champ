# Settings Page Redesign Plan

## Current Issues
1. Theme selector uses 3 separate rows (Light/Dark/System) - could be one row
2. "Data Storage" info card is redundant for non-macOS
3. Hardcoded `/Notes/dailychamp/` path
4. Sync sections are flat, not nested

## New Organization

### Appearance
- **Theme**: Single row with segmented control (Light | Dark | System) ✓ Better UX

### Sync (Native apps only)
- **Nextcloud** (expandable/nested)
  - If configured: Show status, Sync Now, Disconnect
  - If not: Configure button
- **Google Drive** (future - commented out)
  - Same pattern as Nextcloud

### Storage (macOS only)
- **Local File Path**: Show current path + Change button

### Export/Import (Web only)
- Export to File
- Import from File

### Statistics
- Total Entries, Wins, Losses, Pending

### Danger Zone
- Clear All Data

## Implementation Approach
Keep existing code structure but:
1. Add filePath field to Nextcloud config ✅ DONE
2. Use SegmentedButton for theme (Flutter 3.7+)
3. Remove "Data Storage" info card
4. Group Sync options better
