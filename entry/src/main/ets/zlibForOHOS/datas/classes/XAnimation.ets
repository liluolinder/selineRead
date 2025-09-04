import curves from '@ohos.curves'
import Curves from '@ohos.curves'

export class XAnimation {
  private static mode: string = 'auto'

  public static setAnimation(mode: string) {
    XAnimation.mode = mode;
  }

  public static getAnimation(dir: 'left'|'right'|'up'|'bottom', delay: number = 0) {
    const MoveFromTop: object =
      TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease, delay: delay })
        .combine(TransitionEffect.translate({ x: 0, y: -20 })
          .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.TOP),
            TransitionEffect.move(TransitionEdge.TOP))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
    const MoveFromBottom: object =
      TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease, delay: delay })
        .combine(TransitionEffect.translate({ x: 0, y: 20 })
          .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.BOTTOM),
            TransitionEffect.move(TransitionEdge.BOTTOM))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
    const MoveFromStart: object =
      TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease, delay: delay })
        .combine(TransitionEffect.translate({ x: -20, y: 0 })
          .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.START),
            TransitionEffect.move(TransitionEdge.START))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
    const MoveFromEnd: object =
      TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease, delay: delay })
        .combine(TransitionEffect.translate({ x: 20, y: 0 })
          .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.END),
            TransitionEffect.move(TransitionEdge.END))).animation({ curve: Curves.responsiveSpringMotion(0.5,0.85) }))
    switch (XAnimation.mode) {
      case 'auto': {
        switch (dir) {
          case 'up':
            return MoveFromTop;
          case 'bottom':
            return MoveFromBottom;
          case 'left':
            return MoveFromStart;
          case 'right':
            return MoveFromEnd;
        }
      }
      case 'up':
        return MoveFromBottom;
      case 'bottom':
        return MoveFromTop;
      case 'left':
        return MoveFromEnd;
      case 'right':
        return MoveFromStart;
      default:
        return MoveFromBottom;
    }
  }

  public static runWithAnimation(
    fn: Function,
    animate: boolean = true,
    s1: number = 0.4,
    s2: number = 0.7): void {
    if(animate){
      animateToImmediately({ curve: curves.springMotion(s1, s2) }, () => {
        fn();
      });
    }else{
      fn()
    }
  }
}