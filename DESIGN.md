# Animina Design System

This document defines the visual design direction for the Animina dating platform. It serves as the source of truth for all design decisions, ensuring consistency across the application for both human developers and AI agents.

## Design Philosophy: "Coastal Morning"

**Target feel**: Clean, fresh, modern yet approachable - like a refreshing beach morning walk. Trustworthy, calm, and open.

**What we are**:
- Warm and welcoming
- Sophisticated but not pretentious
- Modern but accessible to everyone
- Trustworthy and calm

**What we are NOT**:
- Neon colors or harsh gradients
- Gamified UI ("swipe culture" aesthetics)
- Cold tech vibes
- Overly playful or childish

## Color Palette

### Light Mode

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#F9FAFB` | Page background - clean, airy |
| `surface` | `#FFFFFF` | Cards, modals, elevated surfaces |
| `primary` | `#4A6670` | Main actions, links, emphasis |
| `primary-hover` | `#3A545E` | Primary hover state |
| `secondary` | `#C9A98C` | Secondary actions, warm accents |
| `secondary-hover` | `#B89875` | Secondary hover state |
| `accent` | `#A8C5BE` | Highlights, badges, decorative |
| `text-primary` | `#1F2937` | Main text - strong but not harsh |
| `text-secondary` | `#6B7280` | Secondary text, labels |
| `border` | `#E5E7EB` | Borders, dividers |
| `error` | `#DC6B6B` | Error states |
| `success` | `#5A9B8A` | Success states |
| `warning` | `#D4915A` | Warning states |

### Dark Mode

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#1A2023` | Page background - calm evening |
| `surface` | `#242A2E` | Cards, modals, elevated surfaces |
| `primary` | `#6B8A96` | Main actions - glows softly |
| `primary-hover` | `#7FA0AD` | Primary hover state |
| `secondary` | `#D4B89D` | Secondary actions |
| `secondary-hover` | `#E0C9B2` | Secondary hover state |
| `accent` | `#B8D4CD` | Highlights, badges |
| `text-primary` | `#F3F4F6` | Main text - warm off-white |
| `text-secondary` | `#9CA3AF` | Secondary text |
| `border` | `#374151` | Borders, dividers |
| `error` | `#E88585` | Error states |
| `success` | `#6BB5A2` | Success states |
| `warning` | `#E0A370` | Warning states |

### Color Rationale

- **Slate blue primary**: Trustworthy, calm, modern without being cold
- **Warm sand secondary**: Adds warmth and earthiness, balances the blue
- **Seafoam accent**: Fresh, natural, coastal vibe
- **Blue-gray dark backgrounds**: Sophisticated but not harsh

## Typography

### Font Stack

```css
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
```

System fonts provide excellent performance and feel native on each platform.

### Type Scale

| Name | Tailwind Class | Size | Usage |
|------|---------------|------|-------|
| Hero | `text-3xl md:text-5xl` | 30px → 48px | Main page headings |
| Section | `text-2xl md:text-3xl` | 24px → 30px | Section headings |
| Subheading | `text-xl` | 20px | Subsection headings |
| Body Large | `text-lg` | 18px | Important body text |
| Body | `text-base` | 16px | Default body text |
| Small | `text-sm` | 14px | Timestamps, metadata only |

### Typography Rules

1. **Never use `text-xs`** - Readability is paramount
2. **Minimum body text is 16px** (`text-base`)
3. **Use `text-sm` sparingly** - only for non-essential metadata
4. **Line height**: Use Tailwind defaults (generous spacing)
5. **Font weight**: Normal for body, `font-medium` for emphasis, `font-semibold` for headings

## Spacing

Use Tailwind's default spacing scale consistently:

| Token | Size | Usage |
|-------|------|-------|
| `1` | 4px | Tight spacing |
| `2` | 8px | Small gaps |
| `3` | 12px | Component internal |
| `4` | 16px | Default spacing |
| `6` | 24px | Section spacing |
| `8` | 32px | Large gaps |
| `12` | 48px | Major sections |
| `16` | 64px | Page sections |

## Components

### Buttons

```html
<!-- Primary button -->
<button class="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-hover transition-colors duration-200">
  Action
</button>

<!-- Secondary button -->
<button class="px-4 py-2 bg-secondary text-white rounded-lg hover:bg-secondary-hover transition-colors duration-200">
  Secondary
</button>

<!-- Outline button -->
<button class="px-4 py-2 border border-primary text-primary rounded-lg hover:bg-primary hover:text-white transition-colors duration-200">
  Outline
</button>
```

### Cards

```html
<div class="bg-surface rounded-xl shadow-md p-6">
  <!-- Card content -->
</div>
```

### Styling Principles

- **Rounded corners**: `rounded-lg` for buttons/inputs, `rounded-xl` for cards
- **Shadows**: Soft shadows with `shadow-md`
- **Transitions**: 200ms for hover states
- **Borders**: Use `border` color token, 1px width

## Icons

Use Heroicons via the `<.icon>` component:

```heex
<.icon name="hero-bell" class="size-6" />
<.icon name="hero-bookmark" class="size-6" />
<.icon name="hero-user-circle" class="size-8" />
```

## Logo

The Animina logo is rendered as text in all caps: **ANIMINA**

```html
<span class="text-2xl font-light tracking-tight text-primary">ANIMINA</span>
```

- All caps for visual impact and brand recognition
- `font-light` (300 weight) for elegance
- `tracking-tight` for a cohesive, modern feel
- Primary color (slate blue) for brand consistency

Icon sizes:
- Navigation: `size-6` (24px)
- Inline: `size-5` (20px)
- Small: `size-4` (16px)

## Responsive Design

### Mobile-First Breakpoints

| Breakpoint | Min Width | Usage |
|------------|-----------|-------|
| Default | < 640px | Mobile phones |
| `sm:` | ≥ 640px | Small tablets |
| `md:` | ≥ 768px | Tablets |
| `lg:` | ≥ 1024px | Desktop |
| `xl:` | ≥ 1280px | Large desktop |

### Responsive Patterns

1. **Start mobile, enhance up**: Write base styles for mobile first
2. **Stack to row**: Use `flex-col md:flex-row` patterns
3. **Hide/show**: Use `hidden md:block` for desktop-only elements
4. **Adjust spacing**: Increase padding on larger screens

## Dark Mode

Dark mode is controlled by system preference using the `data-theme` attribute on `<html>`.

### Implementation

- Theme is set via JavaScript on page load based on `prefers-color-scheme`
- User choice persists to `localStorage` under `phx:theme`
- Use CSS custom properties via daisyUI theme system

### Dark Mode Guidelines

1. **Don't just invert colors** - adjust for comfortable viewing
2. **Reduce contrast slightly** in dark mode for less eye strain
3. **Lighten primary colors** so they "glow" on dark backgrounds
4. **Test both modes** before shipping any UI change

## Images

### Unsplash Attribution

All Unsplash images must include proper attribution in the ALT tag:

```html
<img
  src="..."
  alt="Two friends laughing at a coffee shop. Photo by John Doe on Unsplash"
/>
```

Format: `"[Description]. Photo by [Photographer Name] on Unsplash"`

### Image Guidelines

- Choose images with natural lighting
- Prefer authentic, candid moments over staged photos
- Ensure diversity in age, ethnicity, and body type
- Avoid overly polished "stock photo" aesthetic

## Accessibility

### Requirements

1. **Color contrast**: Minimum 4.5:1 for normal text, 3:1 for large text
2. **Focus states**: Visible focus indicators on all interactive elements
3. **Alt text**: All images must have descriptive alt text
4. **Keyboard navigation**: All functionality accessible via keyboard
5. **ARIA labels**: Use on icon-only buttons

### Focus Styles

```css
/* Example focus style */
focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2
```

## Layout Patterns

### Fixed Header with Scrollable Content

```
┌─────────────────────────────────┐
│ NAVBAR (fixed, z-50)            │
├─────────────────────────────────┤
│ FLASH MESSAGES (fixed below)    │
├─────────────────────────────────┤
│                                 │
│ MAIN (scrollable, pt-[header])  │
│                                 │
├─────────────────────────────────┤
│ FOOTER                          │
└─────────────────────────────────┘
```

### Container Widths

- Default max-width: `max-w-7xl` (80rem / 1280px)
- Narrow content: `max-w-3xl` (48rem / 768px)
- Always center: `mx-auto`
- Horizontal padding: `px-4 sm:px-6 lg:px-8`
