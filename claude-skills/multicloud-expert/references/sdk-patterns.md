# Cloud SDK Design Patterns & Retry Engineering

## Universal SDK Resilience Invariants

1. **Exponential Backoff with Jitter:** All API client implementations MUST use full jitter exponential backoff to prevent thundering herd problems on cloud control planes.
2. **Context Cancellation & Timeouts:** Always pass explicit `context.Context` (Go) or timeout parameters (Python) to prevent dangling connection leaks.
3. **Paginated Iteration:** Never consume API list responses without explicit paginators; unpaginated calls will crash when scale exceeds page limits.

## Python Multi-Cloud SDK Pattern (Boto3 & GCP Storage)

```python
import time
import random
from typing import Callable, Any

def retry_with_jitter(func: Callable[[], Any], max_retries: int = 5, base_delay: float = 0.5) -> Any:
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            sleep_time = (base_delay * (2 ** attempt)) + random.uniform(0, 0.1)
            time.sleep(sleep_time)
```

## Go Multi-Cloud SDK Pattern (Context & Pagination)

```go
package main

import (
    "context"
    "time"
    "cloud.google.com/go/storage"
    "google.golang.org/api/iterator"
)

func listBucketObjects(ctx context.Context, bucketName string) ([]string, error) {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    client, err := storage.NewClient(ctx)
    if err != nil {
        return nil, err
    }
    defer client.Close()

    var objectNames []string
    it := client.Bucket(bucketName).Objects(ctx, nil)
    for {
        attrs, err := it.Next()
        if err == iterator.Done {
            break
        }
        if err != nil {
            return nil, err
        }
        objectNames = append(objectNames, attrs.Name)
    }
    return objectNames, nil
}
```
