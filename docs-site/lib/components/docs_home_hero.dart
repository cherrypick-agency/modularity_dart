import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/theme.dart';

import 'docs_nav_link.dart';
import '../theme/docs_responsive.dart';

class DocsHomeHeroAction {
  const DocsHomeHeroAction({
    required this.text,
    required this.href,
    required this.theme,
    this.isExternal = false,
  });

  final String text;
  final String href;
  final String theme;
  final bool isExternal;
}

class DocsHomeHero extends StatelessComponent {
  const DocsHomeHero({
    required this.name,
    required this.text,
    required this.tagline,
    required this.actions,
    super.key,
  });

  final String name;
  final String text;
  final String tagline;
  final List<DocsHomeHeroAction> actions;

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(children: [Style(styles: _styles)]),
      section(classes: 'docs-home-hero', [
        div(classes: 'docs-home-hero-copy', [
          h1(classes: 'docs-home-hero-name', [Component.text(name)]),
          p(classes: 'docs-home-hero-text', [Component.text(text)]),
          p(classes: 'docs-home-hero-tagline', [Component.text(tagline)]),
          if (actions.isNotEmpty)
            div(classes: 'docs-home-hero-actions', [
              for (final action in actions)
                DocsNavLink(
                  to: action.href,
                  target: action.isExternal ? Target.blank : null,
                  attributes: {if (action.isExternal) 'rel': 'noopener'},
                  classes: action.theme == 'brand'
                      ? 'docs-home-hero-action is-brand'
                      : 'docs-home-hero-action is-alt',
                  children: [Component.text(action.text)],
                ),
            ]),
        ]),
        div(classes: 'docs-home-hero-scene', [
          // Connection lines (behind modules)
          div(classes: 'mod-connections', [
            div(classes: 'mod-line mod-line-top', const []),
            div(classes: 'mod-line mod-line-right', const []),
            div(classes: 'mod-line mod-line-bottom', const []),
            div(classes: 'mod-line mod-line-left', const []),
            div(classes: 'mod-line mod-line-diag-tr', const []),
            div(classes: 'mod-line mod-line-diag-bl', const []),
          ]),
          // Center core module
          div(classes: 'mod-node mod-core', [
            span(classes: 'mod-icon', [Component.text('M')]),
            span(classes: 'mod-label', [Component.text('Core')]),
          ]),
          // Orbital modules
          div(classes: 'mod-node mod-orbit mod-o1', [
            span(classes: 'mod-icon', [Component.text('A')]),
            span(classes: 'mod-label', [Component.text('Auth')]),
          ]),
          div(classes: 'mod-node mod-orbit mod-o2', [
            span(classes: 'mod-icon', [Component.text('P')]),
            span(classes: 'mod-label', [Component.text('Pay')]),
          ]),
          div(classes: 'mod-node mod-orbit mod-o3', [
            span(classes: 'mod-icon', [Component.text('U')]),
            span(classes: 'mod-label', [Component.text('User')]),
          ]),
          div(classes: 'mod-node mod-orbit mod-o4', [
            span(classes: 'mod-icon', [Component.text('N')]),
            span(classes: 'mod-label', [Component.text('Nav')]),
          ]),
          // Floating particles
          span(classes: 'docs-home-particle p-one', [Component.text('DI')]),
          span(classes: 'docs-home-particle p-two', [
            Component.text('lifecycle'),
          ]),
          span(classes: 'docs-home-particle p-three', [
            Component.text('scope'),
          ]),
          span(classes: 'docs-home-particle p-four', [
            Component.text('DAG'),
          ]),
        ]),
      ]),
    ]);
  }

  static List<StyleRule> get _styles => [
    // --- Keyframes ---
    css.keyframes('mod-pulse', {
      '0%, 100%': const Styles(raw: {'transform': 'scale(1)', 'opacity': '1'}),
      '50%': const Styles(
        raw: {'transform': 'scale(1.06)', 'opacity': '0.88'},
      ),
    }),
    css.keyframes('mod-orbit-drift', {
      '0%, 100%': const Styles(raw: {'transform': 'translate(0, 0)'}),
      '25%': const Styles(raw: {'transform': 'translate(3px, -5px)'}),
      '50%': const Styles(raw: {'transform': 'translate(-2px, 4px)'}),
      '75%': const Styles(raw: {'transform': 'translate(4px, 2px)'}),
    }),
    css.keyframes('mod-line-pulse', {
      '0%, 100%': const Styles(opacity: 0.18),
      '50%': const Styles(opacity: 0.5),
    }),
    css.keyframes('docs-home-particle-float', {
      '0%, 100%': const Styles(
        opacity: 0,
        raw: {'transform': 'translateY(10px)'},
      ),
      '15%, 85%': const Styles(opacity: 0.62),
      '50%': const Styles(
        opacity: 0.88,
        raw: {'transform': 'translateY(-16px)'},
      ),
    }),
    css.keyframes('docs-home-hero-glow', {
      '0%': const Styles(
        opacity: 0.56,
        raw: {'transform': 'translateX(-50%) scale(1)'},
      ),
      '100%': const Styles(
        opacity: 1,
        raw: {'transform': 'translateX(-50%) scale(1.16)'},
      ),
    }),
    // --- Hero layout ---
    css('.docs-home-hero', [
      css('&').styles(
        display: Display.grid,
        alignItems: AlignItems.center,
        gap: Gap.all(2.5.rem),
        raw: {
          'grid-template-columns': 'minmax(0, 1.15fr) minmax(18rem, 25rem)',
          'position': 'relative',
          'isolation': 'isolate',
        },
      ),
      css('&::before').styles(
        content: '""',
        position: Position.absolute(top: (-5).percent, left: 50.percent),
        width: 38.rem,
        height: 38.rem,
        radius: BorderRadius.circular(999.px),
        pointerEvents: PointerEvents.none,
        filter: Filter.blur(64.px),
        opacity: 0.9,
        zIndex: ZIndex(-1),
        raw: {
          'background':
              'radial-gradient(circle, color-mix(in srgb, var(--docs-shell-accent) 18%, transparent) 0%, color-mix(in srgb, var(--docs-shell-accent-strong) 10%, transparent) 42%, transparent 72%)',
          'transform': 'translateX(-50%)',
          'animation': 'docs-home-hero-glow 6s ease-in-out infinite alternate',
        },
      ),
      // --- Copy ---
      css('.docs-home-hero-copy').styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        alignItems: AlignItems.start,
        raw: {'min-width': '0'},
      ),
      css('.docs-home-hero-name').styles(
        margin: Margin.zero,
        fontSize: 3.65.rem,
        fontWeight: FontWeight.w900,
        color: ContentColors.headings,
        raw: {
          'line-height': '1.02',
          'letter-spacing': '-0.055em',
          'max-width': '12ch',
          'text-wrap': 'balance',
        },
      ),
      css('.docs-home-hero-text').styles(
        margin: Margin.only(top: 0.9.rem),
        fontSize: 1.34.rem,
        fontWeight: FontWeight.w700,
        color: Color('var(--docs-shell-accent-strong)'),
        raw: {'letter-spacing': '-0.025em'},
      ),
      css('.docs-home-hero-tagline').styles(
        margin: Margin.only(top: 0.95.rem),
        maxWidth: 34.rem,
        fontSize: 1.05.rem,
        color: Color('var(--docs-shell-muted)'),
        raw: {'line-height': '1.72', 'text-wrap': 'pretty'},
      ),
      css('.docs-home-hero-actions').styles(
        display: Display.flex,
        flexWrap: FlexWrap.wrap,
        gap: Gap.all(0.9.rem),
        margin: Margin.only(top: 1.6.rem),
      ),
      css('.docs-home-hero-action').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        minHeight: 3.1.rem,
        padding: Padding.symmetric(horizontal: 1.15.rem, vertical: 0.72.rem),
        radius: BorderRadius.circular(1.rem),
        border: Border.all(width: 1.px, color: Color('transparent')),
        fontWeight: FontWeight.w700,
        transition: Transition(
          'transform, box-shadow, background-color, border-color, color',
          duration: 180.ms,
          curve: Curve.easeInOut,
        ),
        raw: {'box-shadow': '0 18px 38px rgba(15, 23, 42, 0.08)'},
      ),
      css(
        '.docs-home-hero-action:hover',
      ).styles(raw: {'transform': 'translateY(-1px)'}),
      css('.docs-home-hero-action:focus-visible').styles(
        outline: Outline(
          width: OutlineWidth(3.px),
          style: OutlineStyle.solid,
          color: Color('var(--docs-shell-focus)'),
          offset: 3.px,
        ),
      ),
      css('.docs-home-hero-action.is-brand').styles(
        color: Colors.white,
        backgroundColor: Color('var(--docs-shell-accent-strong)'),
      ),
      css(
        '.docs-home-hero-action.is-brand:hover',
      ).styles(backgroundColor: Color('var(--docs-shell-accent)')),
      css('.docs-home-hero-action.is-alt').styles(
        color: ContentColors.headings,
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
      ),
      css('.docs-home-hero-action.is-alt:hover').styles(
        color: Color('var(--docs-shell-accent-strong)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
      ),
      // --- Scene (module graph visualization) ---
      css('.docs-home-hero-scene').styles(
        display: Display.flex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        position: Position.relative(),
        width: 100.percent,
        height: 21.rem,
      ),
      // --- Connection lines ---
      css('.mod-connections').styles(
        position: Position.absolute(
          top: Unit.zero,
          left: Unit.zero,
          right: Unit.zero,
          bottom: Unit.zero,
        ),
        pointerEvents: PointerEvents.none,
      ),
      css('.mod-line').styles(
        position: Position.absolute(),
        backgroundColor: Color('var(--docs-shell-accent)'),
        opacity: 0.2,
        raw: {'animation': 'mod-line-pulse 3s ease-in-out infinite'},
      ),
      css('.mod-line-top').styles(
        width: 2.px,
        height: 3.2.rem,
        raw: {
          'left': '50%',
          'top': '10%',
          'transform': 'translateX(-50%)',
          'animation-delay': '0s',
        },
      ),
      css('.mod-line-bottom').styles(
        width: 2.px,
        height: 3.2.rem,
        raw: {
          'left': '50%',
          'bottom': '10%',
          'transform': 'translateX(-50%)',
          'animation-delay': '1.5s',
        },
      ),
      css('.mod-line-left').styles(
        width: 3.2.rem,
        height: 2.px,
        raw: {
          'left': '14%',
          'top': '50%',
          'transform': 'translateY(-50%)',
          'animation-delay': '0.75s',
        },
      ),
      css('.mod-line-right').styles(
        width: 3.2.rem,
        height: 2.px,
        raw: {
          'right': '14%',
          'top': '50%',
          'transform': 'translateY(-50%)',
          'animation-delay': '2.25s',
        },
      ),
      css('.mod-line-diag-tr').styles(
        width: 2.px,
        height: 3.rem,
        raw: {
          'right': '26%',
          'top': '18%',
          'transform': 'rotate(-45deg)',
          'animation-delay': '0.4s',
        },
      ),
      css('.mod-line-diag-bl').styles(
        width: 2.px,
        height: 3.rem,
        raw: {
          'left': '26%',
          'bottom': '18%',
          'transform': 'rotate(-45deg)',
          'animation-delay': '1.9s',
        },
      ),
      // --- Module nodes ---
      css('.mod-node').styles(
        position: Position.absolute(),
        display: Display.flex,
        flexDirection: FlexDirection.column,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        radius: BorderRadius.circular(1.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        raw: {
          'box-shadow':
              '0 12px 36px color-mix(in srgb, var(--docs-shell-shadow) 90%, transparent)',
        },
      ),
      css('.mod-icon').styles(
        fontSize: 1.1.rem,
        fontWeight: FontWeight.w900,
        color: Color('var(--docs-shell-accent-strong)'),
        raw: {'font-family': 'var(--content-code-font)'},
      ),
      css('.mod-label').styles(
        fontSize: 0.6.rem,
        fontWeight: FontWeight.w700,
        color: Color('var(--docs-shell-muted)'),
        textTransform: TextTransform.upperCase,
        letterSpacing: 0.06.rem,
        margin: Margin.only(top: 0.15.rem),
      ),
      // Core module (center, larger)
      css('.mod-core').styles(
        width: 5.5.rem,
        height: 5.5.rem,
        raw: {
          'left': '50%',
          'top': '50%',
          'transform': 'translate(-50%, -50%)',
          'z-index': '2',
          'animation': 'mod-pulse 4s ease-in-out infinite',
          'background':
              'linear-gradient(145deg, var(--docs-shell-surface-elevated) 0%, color-mix(in srgb, var(--docs-shell-accent-soft) 60%, var(--docs-shell-surface-elevated)) 100%)',
          'border-color': 'var(--docs-shell-accent)',
        },
      ),
      css('.mod-core .mod-icon').styles(fontSize: 1.5.rem),
      css('.mod-core .mod-label').styles(fontSize: 0.68.rem),
      // Orbital modules (smaller, positioned around core)
      css('.mod-orbit').styles(
        width: 4.rem,
        height: 4.rem,
        zIndex: ZIndex(1),
      ),
      css('.mod-o1').styles(
        raw: {
          'left': '50%',
          'top': '2%',
          'transform': 'translateX(-50%)',
          'animation': 'mod-orbit-drift 7s ease-in-out infinite',
        },
      ),
      css('.mod-o2').styles(
        raw: {
          'right': '8%',
          'top': '50%',
          'transform': 'translateY(-50%)',
          'animation': 'mod-orbit-drift 7s ease-in-out infinite 1.75s',
        },
      ),
      css('.mod-o3').styles(
        raw: {
          'left': '50%',
          'bottom': '2%',
          'transform': 'translateX(-50%)',
          'animation': 'mod-orbit-drift 7s ease-in-out infinite 3.5s',
        },
      ),
      css('.mod-o4').styles(
        raw: {
          'left': '8%',
          'top': '50%',
          'transform': 'translateY(-50%)',
          'animation': 'mod-orbit-drift 7s ease-in-out infinite 5.25s',
        },
      ),
      // --- Floating particles ---
      css('.docs-home-particle').styles(
        position: Position.absolute(),
        fontWeight: FontWeight.w700,
        color: Color(
          'color-mix(in srgb, var(--docs-shell-accent) 58%, transparent)',
        ),
        opacity: 0,
        pointerEvents: PointerEvents.none,
        raw: {
          'font-family': 'var(--content-code-font)',
          'font-size': '0.78rem',
          'animation': 'docs-home-particle-float 8s ease-in-out infinite',
        },
      ),
      css(
        '.docs-home-particle.p-one',
      ).styles(raw: {'top': '6%', 'right': '2%', 'animation-delay': '0s'}),
      css('.docs-home-particle.p-two').styles(
        raw: {'bottom': '6%', 'left': '0%', 'animation-delay': '2s'},
      ),
      css(
        '.docs-home-particle.p-three',
      ).styles(raw: {'top': '16%', 'left': '6%', 'animation-delay': '4s'}),
      css('.docs-home-particle.p-four').styles(
        raw: {'right': '4%', 'bottom': '16%', 'animation-delay': '6s'},
      ),
      // --- Responsive ---
      downContent([
        css('&').styles(
          gap: Gap.all(2.rem),
          raw: {'grid-template-columns': 'minmax(0, 1fr)'},
        ),
        css('.docs-home-hero-copy').styles(alignItems: AlignItems.center),
        css(
          '.docs-home-hero-name',
        ).styles(fontSize: 3.1.rem, textAlign: TextAlign.center),
        css('.docs-home-hero-text').styles(textAlign: TextAlign.center),
        css('.docs-home-hero-tagline').styles(textAlign: TextAlign.center),
        css(
          '.docs-home-hero-actions',
        ).styles(justifyContent: JustifyContent.center),
        css('.docs-home-hero-scene').styles(height: 18.rem),
      ]),
      downMobile([
        css('.docs-home-hero-name').styles(fontSize: 2.5.rem),
        css('.docs-home-hero-text').styles(fontSize: 1.12.rem),
        css('.docs-home-hero-tagline').styles(fontSize: 0.98.rem),
        css('.docs-home-hero-scene').styles(height: 15.5.rem),
        css('.mod-core').styles(width: 4.5.rem, height: 4.5.rem),
        css('.mod-orbit').styles(width: 3.2.rem, height: 3.2.rem),
      ]),
      downCompact([
        css(
          '.docs-home-hero-actions',
        ).styles(width: 100.percent, raw: {'justify-content': 'stretch'}),
        css(
          '.docs-home-hero-action',
        ).styles(width: 100.percent, raw: {'justify-content': 'center'}),
        css('.docs-home-particle').styles(display: Display.none),
      ]),
    ]),
    css.media(MediaQuery.raw('(prefers-reduced-motion: reduce)'), [
      css('.docs-home-hero::before').styles(raw: {'animation': 'none'}),
      css('.mod-core').styles(raw: {'animation': 'none'}),
      css('.mod-orbit').styles(raw: {'animation': 'none'}),
      css('.mod-line').styles(raw: {'animation': 'none'}),
      css(
        '.docs-home-particle',
      ).styles(display: Display.none, opacity: 0, raw: {'animation': 'none'}),
      css('.docs-home-hero-action').styles(raw: {'transition': 'none'}),
    ]),
  ];
}
