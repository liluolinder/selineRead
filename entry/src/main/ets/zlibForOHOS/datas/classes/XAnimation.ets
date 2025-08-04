import Curves from '@ohos.curves'

export class XAnimation {
  private static MoveFromTop: object =
    TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease })
      .combine(TransitionEffect.translate({ x: 0, y: -20 })
        .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.TOP),
          TransitionEffect.move(TransitionEdge.TOP))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
  private static MoveFromBottom: object =
    TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease })
      .combine(TransitionEffect.translate({ x: 0, y: 20 })
        .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.BOTTOM),
          TransitionEffect.move(TransitionEdge.BOTTOM))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
  private static MoveFromStart: object =
    TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease })
      .combine(TransitionEffect.translate({ x: -20, y: 0 })
        .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.START),
          TransitionEffect.move(TransitionEdge.START))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
  private static MoveFromEnd: object =
    TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease })
      .combine(TransitionEffect.translate({ x: 20, y: 0 })
        .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.END),
          TransitionEffect.move(TransitionEdge.END))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
  private static mode: string = 'auto'

  public static setAnimation(mode: string) {
    XAnimation.mode = mode;
  }

  public static getAnimation(dir: string) {
    switch (XAnimation.mode) {
      case 'auto': {
        switch (dir) {
          case 'up':
            return XAnimation.MoveFromTop;
          case 'bottom':
            return XAnimation.MoveFromBottom;
          case 'left':
            return XAnimation.MoveFromStart;
          case 'right':
            return XAnimation.MoveFromEnd;
          default:
            return XAnimation.MoveFromBottom;
        }
      }
      case 'up':
        return XAnimation.MoveFromBottom;
      case 'bottom':
        return XAnimation.MoveFromTop;
      case 'left':
        return XAnimation.MoveFromEnd;
      case 'right':
        return XAnimation.MoveFromStart;
      default:
        return XAnimation.MoveFromBottom;
    }
  }

  public static runWithAnimation(
    fn: Function,
    duration: number = 200,
    curve: Curve = Curve.Smooth): void {
    animateTo({ duration: duration, curve: curve }, () => {
      fn();
    });
  }
}