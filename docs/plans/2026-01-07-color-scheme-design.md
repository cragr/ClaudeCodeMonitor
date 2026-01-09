# Cross-Platform Color Scheme Design

**Goal:** Create a neutral dark color scheme that feels native and pleasing on both Windows and macOS.

**Design Decisions:**
- Neutral Dark tone (softer grays, professional feel)
- Teal/Cyan primary accent (modern, good contrast)
- Muted/Subtle intensity (desaturated colors, less fatiguing)

---

## Color Palette

### Backgrounds
| Token | Hex | Usage |
|-------|-----|-------|
| `bg-primary` | `#1a1d21` | Main app background |
| `bg-secondary` | `#22262b` | Sidebar, elevated surfaces |
| `bg-card` | `#282c33` | Cards, panels, modals |
| `bg-card-hover` | `#2f343c` | Hover states on cards |

### Borders
| Token | Hex | Usage |
|-------|-----|-------|
| `border-primary` | `#3d424a` | Card borders, dividers |
| `border-secondary` | `#2f343c` | Subtle separators |
| `border-focus` | `#5b9a8b` | Focus rings (muted teal) |

### Text
| Token | Hex | Usage |
|-------|-----|-------|
| `text-primary` | `#e8eaed` | Headlines, important values |
| `text-secondary` | `#9aa0a9` | Labels, descriptions |
| `text-muted` | `#6b727c` | Timestamps, hints, disabled |

### Accents
| Token | Hex | Usage |
|-------|-----|-------|
| `accent-primary` | `#5b9a8b` | Primary actions, links, active states |
| `accent-green` | `#6b9b7a` | Success, positive changes, connected |
| `accent-red` | `#c47272` | Errors, negative changes, disconnected |
| `accent-yellow` | `#c9a855` | Warnings, highlights |
| `accent-blue` | `#6b8fc4` | Info, secondary data |
| `accent-purple` | `#9b7bb8` | Tertiary data, model indicators |
| `accent-orange` | `#c4896b` | Accent data, sessions |

---

## Rationale

### Backgrounds
Neutral grays without strong blue or warm undertones. Slightly lighter than GitHub-dark (#1a vs #0d) to reduce the "void" feeling on Windows where system chrome is typically lighter.

### Borders
More visible than minimal macOS aesthetic to help define card edges. Windows users expect clearer visual boundaries between UI elements.

### Text
Off-white primary (#e8eaed, not pure #fff) reduces glare. Mid-grays work well for both Windows ClearType and macOS font smoothing.

### Accents
~30% desaturated from typical UI colors. Charts and metrics feel informative rather than alarming. All colors pass WCAG contrast requirements against card backgrounds.
