// Generated-copy template. Product identity, permissions and business input stay consumer-owned.
export interface CangHuiSurfaceIngress {
  attach(nativeWindow: bigint, pixelWidth: number, pixelHeight: number, scaleMilli: number,
    generation: number): number;
  resize(pixelWidth: number, pixelHeight: number, scaleMilli: number, generation: number): number;
  frame(timestampNanos: bigint, targetTimestampNanos: bigint, generation: number): number;
  detach(generation: number): number;
}

export type CangHuiPointerPacket = {
  phase: 'down' | 'move' | 'up' | 'cancel'; x: number; y: number; pointerId: number;
  generation: number; source: 'mouse' | 'touch' | 'pen'; buttons: number; pressure: number;
};

export type CangHuiKeyPacket = {
  phase: 'down' | 'up'; keyCode: number; scanCode: number; repeat: boolean;
  modifiers: number; generation: number;
};

export class CangHuiHostMailbox<T> {
  private readonly capacity: number;
  private values: T[] = [];
  constructor(capacity: number = 64) { this.capacity = Math.max(1, capacity); }
  push(value: T): void {
    if (this.values.length >= this.capacity) this.values.shift();
    this.values.push(value);
  }
  drain(): T[] { const result = this.values; this.values = []; return result; }
}

export class CangHuiXComponentHost {
  private generation: number = 0;
  readonly pointerMailbox = new CangHuiHostMailbox<CangHuiPointerPacket>();
  readonly keyMailbox = new CangHuiHostMailbox<CangHuiKeyPacket>();
  constructor(private readonly ingress: CangHuiSurfaceIngress) {}
  onSurfaceCreated(nativeWindow: bigint, width: number, height: number, scaleMilli: number): number {
    this.generation += 1;
    this.ingress.attach(nativeWindow, width, height, scaleMilli, this.generation);
    return this.generation;
  }
  onSurfaceChanged(width: number, height: number, scaleMilli: number): void {
    this.ingress.resize(width, height, scaleMilli, this.generation);
  }
  onFrame(timestampNanos: bigint, targetTimestampNanos: bigint): void {
    this.ingress.frame(timestampNanos, targetTimestampNanos, this.generation);
  }
  onSurfaceDestroyed(): void { this.ingress.detach(this.generation); }
  onPointer(packet: Omit<CangHuiPointerPacket, 'generation'>): void {
    this.pointerMailbox.push({ ...packet, generation: this.generation });
  }
  onKey(packet: Omit<CangHuiKeyPacket, 'generation'>): void {
    this.keyMailbox.push({ ...packet, generation: this.generation });
  }
  currentGeneration(): number { return this.generation; }
}
