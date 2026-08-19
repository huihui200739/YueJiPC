export function errorMessage(error: Error | string, fallback: string): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string' && error.length > 0) {
    return error;
  }
  return fallback;
}

export class TransactionFailureError extends Error {
  readonly rollbackFailed: boolean;

  constructor(message: string, rollbackFailed: boolean) {
    super(message);
    this.rollbackFailed = rollbackFailed;
  }
}

export function transactionFailure(
  operation: string,
  error: Error | string,
  rollbackError?: Error | string
): TransactionFailureError {
  const reason = errorMessage(error, '未知数据库错误');
  if (rollbackError !== undefined) {
    const rollbackReason = errorMessage(rollbackError, '未知回滚错误');
    return new TransactionFailureError(
      `${operation}: ${reason}; rollback failed: ${rollbackReason}`,
      true
    );
  }
  return new TransactionFailureError(`${operation}: ${reason}`, false);
}
