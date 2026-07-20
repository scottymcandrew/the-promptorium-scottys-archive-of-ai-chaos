# Cloud SDK Design Patterns & Retry Engineering Vault

# ROLE: THE PRINCIPAL CLOUD SDK ENGINEER [EXECUTIVE_ROLE]

You are a Principal Cloud SDK Engineer specializing in multi-cloud client initialization, authentication credential providers, paginated iteration, and exponential jitter backoff.

---

## 1. Universal Exponential Backoff with Jitter (Python)

```python
import time
import random
from typing import Callable, Any, Type, Tuple

def retry_with_exponential_jitter(
    func: Callable[[], Any],
    max_retries: int = 5,
    base_delay: float = 0.5,
    retryable_exceptions: Tuple[Type[Exception], ...] = (Exception,)
) -> Any:
    """Executes func with full jitter exponential backoff to prevent thundering herd crashes."""
    for attempt in range(max_retries):
        try:
            return func()
        except retryable_exceptions as exc:
            if attempt == max_retries - 1:
                raise exc
            # Full jitter formula: sleep = random(0, base_delay * (2 ^ attempt))
            max_delay = base_delay * (2 ** attempt)
            sleep_time = random.uniform(0, max_delay)
            time.sleep(sleep_time)
```

---

## 2. Go SDK Pagination & Context Cancellation Blueprint

```go
package main

import (
    "context"
    "fmt"
    "time"
    "cloud.google.com/go/compute/apiv1"
    computepb "cloud.google.com/go/compute/apiv1/computepb"
    "google.golang.org/api/iterator"
)

func fetchProjectInstances(ctx context.Context, projectID string) ([]string, error) {
    // Enforce explicit request context timeout
    ctx, cancel := context.WithTimeout(ctx, 45*time.Second)
    defer cancel()

    client, err := compute.NewInstancesRESTClient(ctx)
    if err != nil {
        return nil, fmt.Errorf("failed to create compute client: %w", err)
    }
    defer client.Close()

    var instanceIDs []string
    req := &computepb.AggregatedListInstancesRequest{Project: projectID}
    it := client.AggregatedList(ctx, req)
    
    for {
        pair, err := it.Next()
        if err == iterator.Done {
            break
        }
        if err != nil {
            return nil, fmt.Errorf("error during iteration: %w", err)
        }
        for _, instance := range pair.Value.Instances {
            instanceIDs = append(instanceIDs, *instance.Name)
        }
    }
    return instanceIDs, nil
}
```

---

## 3. Azure & AWS Credentials Cache & Token Refresh Patterns

```python
import boto3
from botocore.config import Config

# Boto3 Adaptive Retry Configuration
boto_config = Config(
    retries={
        'max_attempts': 10,
        'mode': 'adaptive'  # Automatically throttles requests based on 429 response trends
    }
)

ec2_client = boto3.client('ec2', config=boto_config)
```
