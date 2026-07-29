import ShadcnUI
import SwiftUI

// MARK: - Tokens

struct TokensDemo: View {
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    private var swatches: [(String, Color)] {
        [
            ("background", palette.background),
            ("foreground", palette.foreground),
            ("card", palette.card),
            ("popover", palette.popover),
            ("primary", palette.primary),
            ("secondary", palette.secondary),
            ("muted", palette.muted),
            ("muted-foreground", palette.mutedForeground),
            ("accent", palette.accent),
            ("destructive", palette.destructive),
            ("border", palette.border),
            ("input", palette.input),
            ("ring", palette.ring),
        ]
    }

    var body: some View {
        GalleryHeading(
            title: "Design tokens",
            subtitle: "shadcn's neutral base colour, converted from OKLCH to sRGB at build time."
        )

        GalleryBlock("Colours") {
            ShadcnWrapLayout(spacing: Space.x3, lineSpacing: Space.x3) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: Space.x1_5) {
                        RoundedRectangle(cornerRadius: theme.radius.md, style: .continuous)
                            .fill(color)
                            .frame(width: 120, height: 48)
                            .shadcnBorder(palette.border, cornerRadius: theme.radius.md)
                        Text(name)
                            .font(theme.typography.mono(theme.typography.xs))
                            .foregroundStyle(palette.mutedForeground)
                    }
                }
            }
        }

        GalleryBlock("Radius scale") {
            HStack(spacing: Space.x4) {
                ForEach(
                    [
                        ("sm", theme.radius.sm), ("md", theme.radius.md),
                        ("lg", theme.radius.lg), ("xl", theme.radius.xl),
                    ],
                    id: \.0
                ) { name, radius in
                    VStack(spacing: Space.x1_5) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(palette.secondary)
                            .frame(width: 72, height: 56)
                            .shadcnBorder(palette.border, cornerRadius: radius)
                        Text("\(name) · \(Int(radius))pt")
                            .font(theme.typography.mono(theme.typography.xs))
                            .foregroundStyle(palette.mutedForeground)
                    }
                }
            }
        }

        GalleryBlock("Type scale") {
            VStack(alignment: .leading, spacing: Space.x2) {
                typeRow("text-xs", theme.typography.xs)
                typeRow("text-sm", theme.typography.sm)
                typeRow("text-base", theme.typography.base)
                typeRow("text-lg", theme.typography.lg)
                typeRow("text-xl", theme.typography.xl)
                typeRow("text-2xl", theme.typography.xl2)
            }
        }
    }

    private func typeRow(_ name: String, _ step: ShadcnTypography.Step) -> some View {
        HStack(spacing: Space.x4) {
            Text(name)
                .font(theme.typography.mono(theme.typography.xs))
                .foregroundStyle(palette.mutedForeground)
                .frame(width: 80, alignment: .leading)
            Text("The quick brown fox")
                .font(theme.typography.sans(step))
        }
    }
}

// MARK: - Buttons

struct ButtonsDemo: View {
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    private let variants: [(String, ShadcnButtonVariant)] = [
        ("default", .primary), ("secondary", .secondary), ("destructive", .destructive),
        ("outline", .outline), ("ghost", .ghost), ("link", .link),
    ]

    var body: some View {
        GalleryHeading(
            title: "Button",
            subtitle: "Six variants and eight sizes, matching buttonVariants() exactly."
        )

        GalleryBlock("Variants") {
            ShadcnWrapLayout(spacing: Space.x3, lineSpacing: Space.x3) {
                ForEach(variants, id: \.0) { name, variant in
                    ShadcnButton(name, variant: variant) {}
                }
            }
        }

        GalleryBlock("Sizes") {
            HStack(alignment: .center, spacing: Space.x3) {
                ShadcnButton("xs", variant: .outline, size: .xs) {}
                ShadcnButton("Small", variant: .outline, size: .small) {}
                ShadcnButton("Default", variant: .outline) {}
                ShadcnButton("Large", variant: .outline, size: .large) {}
            }
        }

        GalleryBlock("Icon sizes") {
            HStack(alignment: .center, spacing: Space.x3) {
                ShadcnButton(icon: ShadcnIcon.plus, variant: .outline, size: .iconXS) {}
                ShadcnButton(icon: ShadcnIcon.plus, variant: .outline, size: .iconSM) {}
                ShadcnButton(icon: ShadcnIcon.plus, variant: .outline, size: .icon) {}
                ShadcnButton(icon: ShadcnIcon.plus, variant: .outline, size: .iconLG) {}
            }
        }

        GalleryBlock("With icons") {
            HStack(spacing: Space.x3) {
                ShadcnButton("New chat", systemImage: ShadcnIcon.plus) {}
                ShadcnButton("Copy", systemImage: ShadcnIcon.copy, variant: .secondary) {}
                ShadcnButton("Delete", systemImage: ShadcnIcon.trash, variant: .destructive) {}
            }
        }

        GalleryBlock("Disabled") {
            HStack(spacing: Space.x3) {
                ShadcnButton("Disabled") {}.disabled(true)
                ShadcnButton("Disabled", variant: .outline) {}.disabled(true)
                ShadcnButton("Disabled", variant: .ghost) {}.disabled(true)
            }
        }

        GalleryBlock("Button group") {
            ShadcnButtonGroup {
                ShadcnButton(icon: ShadcnIcon.chevronLeft, variant: .ghost, size: .iconSM) {}
                ShadcnButtonGroupText("1 of 3")
                ShadcnButton(icon: ShadcnIcon.chevronRight, variant: .ghost, size: .iconSM) {}
            }
        }
    }
}

// MARK: - Badges

struct BadgesDemo: View {
    var body: some View {
        GalleryHeading(
            title: "Badge",
            subtitle: "rounded-full pills at text-xs / font-medium."
        )

        GalleryBlock("Variants") {
            ShadcnWrapLayout(spacing: Space.x2, lineSpacing: Space.x2) {
                ShadcnBadge("Default")
                ShadcnBadge("Secondary", variant: .secondary)
                ShadcnBadge("Destructive", variant: .destructive)
                ShadcnBadge("Outline", variant: .outline)
                ShadcnBadge("Ghost", variant: .ghost)
                ShadcnBadge("Link", variant: .link)
            }
        }

        GalleryBlock("With icons") {
            ShadcnWrapLayout(spacing: Space.x2, lineSpacing: Space.x2) {
                ShadcnBadge("Verified", systemImage: ShadcnIcon.check, variant: .secondary)
                ShadcnBadge(
                    "Completed",
                    systemImage: ShadcnIcon.checkCircle,
                    iconTint: .green,
                    variant: .secondary
                )
                ShadcnBadge("8 tokens", systemImage: ShadcnIcon.cpu, variant: .outline)
            }
        }
    }
}

// MARK: - Forms

struct FormsDemo: View {
    @State private var text = ""
    @State private var notes = ""
    @State private var model: String? = "sonnet"
    @State private var isOn = true
    @State private var isChecked = true
    @State private var tab = 0

    var body: some View {
        GalleryHeading(
            title: "Form controls",
            subtitle: "Input, Textarea, Select, Switch, Checkbox and Tabs."
        )

        GalleryBlock("Input") {
            VStack(alignment: .leading, spacing: Space.x3) {
                ShadcnTextField("Email address", text: $text)
                    .frame(width: 320)
                ShadcnTextField("Disabled", text: .constant(""))
                    .frame(width: 320)
                    .disabled(true)
            }
        }

        GalleryBlock("Textarea") {
            ShadcnTextEditor("Tell us what you think…", text: $notes)
                .frame(width: 420)
        }

        GalleryBlock("Select") {
            ShadcnSelect(
                "Select a model",
                selection: $model,
                width: 220,
                // Lets a screenshot pass capture the menu open, which is the
                // only state where stacking against later siblings matters.
                startsOpen: false,
                options: [
                    ("opus", "Claude Opus 5"),
                    ("sonnet", "Claude Sonnet 5"),
                    ("haiku", "Claude Haiku 4.5"),
                ]
            )
        }

        GalleryBlock("Switch & Checkbox") {
            HStack(spacing: Space.x6) {
                HStack(spacing: Space.x2) {
                    ShadcnSwitch(isOn: $isOn)
                    Text("Enabled")
                }
                HStack(spacing: Space.x2) {
                    ShadcnSwitch(isOn: $isOn, size: .small)
                    Text("Small")
                }
                HStack(spacing: Space.x2) {
                    ShadcnCheckbox(isChecked: $isChecked)
                    Text("Accept terms")
                }
            }
        }

        GalleryBlock("Tabs") {
            VStack(alignment: .leading, spacing: Space.x4) {
                ShadcnTabs(
                    selection: $tab,
                    items: [(0, "Account"), (1, "Password"), (2, "Team")]
                )
                ShadcnTabs(
                    selection: $tab,
                    variant: .line,
                    items: [(0, "Account"), (1, "Password"), (2, "Team")]
                )
            }
        }
    }
}

// MARK: - Cards & feedback

struct CardsDemo: View {
    var body: some View {
        GalleryHeading(
            title: "Card & feedback",
            subtitle: "Card, Alert, Avatar, Progress, Skeleton and Separator."
        )

        GalleryBlock("Card") {
            ShadcnCard {
                ShadcnCardHeader {
                    ShadcnCardTitle("Model settings")
                    ShadcnCardDescription("Choose which model answers your prompts.")
                } action: {
                    ShadcnButton(icon: ShadcnIcon.dotsHorizontal, variant: .ghost, size: .iconSM) {}
                }
                ShadcnCardContent {
                    Text("Opus is slower but stronger at multi-step reasoning.")
                }
                ShadcnCardFooter {
                    ShadcnButton("Save", size: .small) {}
                    ShadcnButton("Cancel", variant: .outline, size: .small) {}
                }
            }
            .frame(maxWidth: 460)
        }

        GalleryBlock("Alert") {
            VStack(spacing: Space.x3) {
                ShadcnAlert(systemImage: ShadcnIcon.info) {
                    ShadcnAlertTitle("Heads up!")
                    ShadcnAlertDescription("You can add components to your app using the CLI.")
                }
                ShadcnAlert(variant: .destructive, systemImage: ShadcnIcon.alertTriangle) {
                    ShadcnAlertTitle("Something went wrong")
                    ShadcnAlertDescription("Your session expired. Please sign in again.")
                }
            }
            .frame(maxWidth: 460)
        }

        GalleryBlock("Avatar") {
            HStack(spacing: Space.x3) {
                ShadcnAvatar(initials: "JK", size: .small)
                ShadcnAvatar(initials: "JK")
                ShadcnAvatar(initials: "JK", size: .large)
            }
        }

        GalleryBlock("Progress & Skeleton") {
            VStack(alignment: .leading, spacing: Space.x4) {
                ShadcnProgress(value: 0.62).frame(width: 320)
                VStack(alignment: .leading, spacing: Space.x2) {
                    ShadcnSkeleton(width: 320, height: 12)
                    ShadcnSkeleton(width: 240, height: 12)
                }
            }
        }

        GalleryBlock("Separator") {
            VStack(spacing: Space.x3) {
                ShadcnSeparator()
                HStack(spacing: Space.x3) {
                    Text("Left")
                    ShadcnSeparator(.vertical).frame(height: 16)
                    Text("Right")
                }
            }
            .frame(maxWidth: 320)
        }
    }
}

// MARK: - Overlays

struct OverlaysDemo: View {
    @State private var showPopover = false
    @State private var showMenu = false
    @State private var showDialog = false

    var body: some View {
        GalleryHeading(
            title: "Overlays",
            subtitle: "Tooltip, Popover, Dropdown menu, Hover card and Dialog."
        )

        GalleryBlock("Tooltip") {
            HStack(spacing: Space.x4) {
                ShadcnButton("Hover me", variant: .outline) {}
                    .shadcnTooltip("This is a tooltip")
                ShadcnButton(icon: ShadcnIcon.copy, variant: .ghost, size: .iconSM) {}
                    .shadcnTooltip("Copy to clipboard", edge: .bottom)
            }
            .padding(.vertical, Space.x8)
        }

        GalleryBlock("Popover & Dropdown") {
            HStack(spacing: Space.x4) {
                ShadcnPopover(isPresented: $showPopover) {
                    ShadcnButton("Open popover", variant: .outline) {
                        showPopover.toggle()
                    }
                } content: {
                    VStack(alignment: .leading, spacing: Space.x2) {
                        ShadcnCardTitle("Dimensions")
                        ShadcnCardDescription("Set the dimensions for the layer.")
                    }
                }

                ShadcnDropdownMenu(isPresented: $showMenu) {
                    ShadcnButton("Open menu", variant: .outline) { showMenu.toggle() }
                } content: {
                    ShadcnMenuLabel("My account")
                    ShadcnMenuItem("Profile", systemImage: "person") {}
                    ShadcnMenuItem("Settings", systemImage: "gearshape") {}
                    ShadcnMenuSeparator()
                    ShadcnMenuItem("Log out", systemImage: "arrow.right.square", isDestructive: true) {}
                }
            }
            .padding(.bottom, 160)
        }

        GalleryBlock("Dialog") {
            ShadcnButton("Open dialog", variant: .outline) { showDialog = true }
        }
    }
}
