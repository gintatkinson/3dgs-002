import {
  Counter32 as ICounter32,
  Counter64 as ICounter64,
  Gauge32 as IGauge32,
  Gauge64 as IGauge64,
  Timeticks as ITimeticks,
  NumericMetricsSubsystem as INumericMetricsSubsystem
} from '../types';

/**
 * 32-bit Counter implementation.
 * Wraps to 0 after reaching 2^32 - 1 (4294967295).
 */
export class Counter32 implements ICounter32 {
  value: number;

  constructor(initialValue: number = 0) {
    this.value = initialValue % 4294967296;
  }

  increment(): void {
    this.value = (this.value + 1) % 4294967296;
  }
}

/**
 * 64-bit Counter implementation.
 * Uses BigInt internally to prevent loss of precision, wraps at 2^64 - 1.
 */
export class Counter64 implements ICounter64 {
  private internalVal: bigint;

  constructor(initialValue: number = 0) {
    this.internalVal = BigInt(initialValue) % 18446744073709551616n;
  }

  get value(): number {
    return Number(this.internalVal);
  }

  set value(val: number) {
    this.internalVal = BigInt(val) % 18446744073709551616n;
  }

  increment(): void {
    this.internalVal = (this.internalVal + 1n) % 18446744073709551616n;
  }
}

/**
 * 32-bit Gauge implementation.
 * Cannot be negative.
 */
export class Gauge32 implements IGauge32 {
  value: number;

  constructor(initialValue: number = 0) {
    if (initialValue < 0) {
      throw new Error("Gauge range limit violated: value cannot be negative");
    }
    this.value = initialValue;
  }

  setValue(val: number): void {
    if (val < 0) {
      throw new Error("Gauge range limit violated: value cannot be negative");
    }
    this.value = val;
  }
}

/**
 * 64-bit Gauge implementation.
 * Cannot be negative.
 */
export class Gauge64 implements IGauge64 {
  value: number;

  constructor(initialValue: number = 0) {
    if (initialValue < 0) {
      throw new Error("Gauge range limit violated: value cannot be negative");
    }
    this.value = initialValue;
  }

  setValue(val: number): void {
    if (val < 0) {
      throw new Error("Gauge range limit violated: value cannot be negative");
    }
    this.value = val;
  }
}

/**
 * Timeticks metric implementation.
 */
export class Timeticks implements ITimeticks {
  value: number;

  constructor(initialValue: number = 0) {
    this.value = initialValue;
  }

  increment(): void {
    this.value++;
  }
}

/**
 * NumericMetricsSubsystem implementation.
 */
export class NumericMetricsSubsystem implements INumericMetricsSubsystem {
  c32: Counter32;
  c64: Counter64;
  g32: Gauge32;
  g64: Gauge64;
  ticks: Timeticks;

  constructor() {
    this.c32 = new Counter32();
    this.c64 = new Counter64();
    this.g32 = new Gauge32();
    this.g64 = new Gauge64();
    this.ticks = new Timeticks();
  }
}
