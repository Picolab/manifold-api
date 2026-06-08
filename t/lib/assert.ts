export function assertTruthy<T>(
  value: T | null | undefined | false,
  message: string
): asserts value is T {
  if (!value) {
    throw new Error(message);
  }
}

export function assertIncludes(actual: string[], required: string[], label: string): void {
  const missing = required.filter(rid => !actual.includes(rid));
  if (missing.length > 0) {
    throw new Error(
      `${label}: missing ruleset(s) ${missing.join(", ")} (installed: ${actual.sort().join(", ")})`
    );
  }
}
