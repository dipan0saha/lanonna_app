import re
from pathlib import Path


def test_push_subscriptions_define_exponential_retry_backoff():
    pubsub_tf = (
        Path(__file__).resolve().parents[3]
        / "infra/terraform/modules/platform/pubsub.tf"
    ).read_text()
    assert pubsub_tf.count("retry_policy {") >= 2
    assert 'minimum_backoff = "10s"' in pubsub_tf
    assert 'maximum_backoff = "600s"' in pubsub_tf
    assert re.search(r"pubsub_max_delivery_attempts\s*=\s*12", pubsub_tf)
