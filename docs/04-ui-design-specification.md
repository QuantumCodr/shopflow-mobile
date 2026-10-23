# ShopFlow --- UI Design Specification

**Status:** Initial design direction; values may be refined after
prototype feedback.

## 1. Design intent

ShopFlow should feel modern, calm, trustworthy and practical. It should
look appropriate for everyday shop operations rather than a generic demo
or an overly decorative consumer app.

## 2. Initial visual direction

-   **Primary color:** Deep green, initially `#176B55`.
-   **Background:** Soft neutral, initially `#F7F9F8`.
-   **Surface:** White.
-   **Primary text:** Dark green-black / near-black.
-   **Accent and status colors:** Use semantic colors for success,
    warning and error; verify contrast in implementation.
-   **Typography:** Use the platform's readable default typography
    initially. Add custom fonts only when they improve the product.
-   **Corners:** Moderately rounded cards and fields; avoid excessive
    pill-shaped elements.
-   **Elevation:** Prefer clear surface contrast over heavy shadows.

These are starter tokens, not a final brand identity. Test them on
actual Android screens and revise based on contrast and usability.

## 3. Layout principles

-   Design for narrow Android screens first.
-   Respect system safe areas.
-   Use scrolling for content that may exceed screen height.
-   Avoid fixed widths that break on smaller phones.
-   Use responsive constraints for cards and forms.
-   Keep the primary action visually prominent.
-   Maintain consistent spacing and alignment.

## 4. Suggested spacing scale

Use a small, consistent spacing scale rather than arbitrary values
throughout the app:

  Token     Value Typical use
  ------- ------- --------------------------
  XS         4 px Small internal gap
  S          8 px Compact spacing
  M         12 px Related components
  L         16 px Standard padding
  XL        24 px Section separation
  XXL       32 px Major section separation

These are logical design values to implement consistently; adjust when
device testing shows a better choice.

## 5. Core components

### App shell

-   Consistent application title and screen structure.
-   Stable navigation between Home, Products, Inventory and Settings.
-   Clear selected-navigation state.
-   Avoid showing navigation destinations that have no meaningful
    implementation.

### Buttons

-   Primary button for the main action on a screen.
-   Secondary or text action for alternatives.
-   Disabled/loading state during an in-progress operation.
-   Clear labels such as "Save product" rather than ambiguous "OK" where
    possible.

### Product list item

-   Product name.
-   Agreed secondary detail, such as SKU or category.
-   Selling price where appropriate.
-   Stock status where relevant.
-   A clear way to open product details.

### Summary card

-   Label, value and optional icon.
-   Consistent height and padding.
-   Accessible text contrast.
-   Do not use color alone to communicate status.

### Forms

-   Persistent labels rather than relying only on placeholder text.
-   Appropriate keyboard type.
-   Inline validation.
-   Clear required/optional distinction.
-   Unsaved-input protection when leaving a form if needed.

### Feedback

-   Use inline messages for field-specific errors.
-   Use snackbars or similarly brief feedback for simple confirmed
    outcomes.
-   Use dialogs for decisions that require deliberate confirmation.
-   Provide a retry or recovery path when practical.

## 6. Accessibility

-   Maintain readable font sizes and contrast.
-   Provide meaningful labels for icon-only controls.
-   Do not communicate low stock, errors or success by color alone.
-   Ensure touch targets are comfortable.
-   Respect platform text scaling where possible.
-   Test with TalkBack and Android accessibility settings before
    release.

## 7. UI states

Each data-driven screen must define loading, populated, empty, error,
offline and stale-cache states as applicable. Do not use a static zero
or empty list to conceal a failed request.

## 8. Flutter implementation guidance

-   Create reusable widgets for repeated patterns.
-   Keep widgets focused on presentation and user interaction.
-   Store shared design tokens in a central theme or design-system
    location.
-   Avoid duplicating the same colors, spacing and text styles
    throughout the app.
-   Prefer composition of small widgets over a single enormous `build`
    method.
-   Do not abstract a component until reuse or clarity justifies the
    abstraction.

## 9. Prototype review checklist

-   Does the screen communicate its purpose within a few seconds?
-   Is the next action obvious?
-   Can the screen fit and scroll on a small phone?
-   Are long product names and large numbers handled?
-   Are empty and failure states helpful?
-   Is the interface clear in light conditions and at larger text sizes?
