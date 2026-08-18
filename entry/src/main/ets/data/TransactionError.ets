export function errorMessage(error: Error | string, fallback: string): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string' && error.length > 0) {
    return error;
  }
  return fallback;
}

export function transactionFailure(
  operation: string,
  error: Error | string,
  rollbackError?: Error | string
): Error {
  const reason = errorMessage(error, '未知数据库错误');
  if (rollbackError !== undefined) {
    const rollbackReason = errorMessage(rollbackError, '未知回滚错误');
    return new Error(`${operation}: ${reason}; rollback failed: ${rollbackReason}`);
  }
  return new Error(`${operation}: ${reason}`);
}
