export type CangHuiCaretRect = { x: number; y: number; width: number; height: number };
export type CangHuiSelection = { startUtf8: number; endUtf8: number };
export type CangHuiComposition = {
  phase: 'begin' | 'update' | 'commit' | 'cancel'; text: string;
  startUtf8: number; lengthUtf8: number; generation: number;
};

// The application binds this contract to its actual Harmony text-input controller. CangHui owns
// focus/caret/selection truth; the host owns the system IME object and never guesses byte offsets.
export interface CangHuiTextInputIngress {
  focus(focusId: string, caret: CangHuiCaretRect, selection: CangHuiSelection, generation: number): void;
  blur(focusId: string, generation: number): void;
  commit(text: string, generation: number): void;
  compose(value: CangHuiComposition): void;
  deleteBackward(generation: number): void;
  submit(generation: number): void;
  synchronizeSelection(selection: CangHuiSelection, generation: number): void;
}

// The host must drop callbacks from a retired focus generation before crossing the native bridge.
export class CangHuiTextInputSession {
  private focusId: string = '';
  private generation: number = 0;
  constructor(private readonly ingress: CangHuiTextInputIngress) {}
  begin(focusId: string, caret: CangHuiCaretRect, selection: CangHuiSelection): number {
    this.generation += 1;
    this.focusId = focusId;
    this.ingress.focus(focusId, caret, selection, this.generation);
    return this.generation;
  }
  end(): void {
    if (this.focusId.length > 0) this.ingress.blur(this.focusId, this.generation);
    this.focusId = '';
  }
  accepts(generation: number): boolean {
    return this.focusId.length > 0 && generation === this.generation;
  }
  currentGeneration(): number { return this.generation; }
}
