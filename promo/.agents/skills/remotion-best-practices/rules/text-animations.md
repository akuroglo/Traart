---
name: text-animations
description: Typography and text animation patterns for Remotion.
metadata:
  tags: typography, text, typewriter, highlighter ken
---

## Text animations

Based on `useCurrentFrame()`, reduce the string character by character to create a typewriter effect.

## Typewriter Effect

Use `useCurrentFrame()` with string slicing for an advanced typewriter effect with a blinking cursor and a pause after the first sentence.

Always use string slicing for typewriter effects. Never use per-character opacity.

## Word Highlighting

Animate a word highlight like with a highlighter pen using interpolated width/background transitions.
