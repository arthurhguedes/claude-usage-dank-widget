class FakeWindow:
    """Duble minimo de claude_usage_monitor.api_usage.UsageWindow para os testes."""

    def __init__(self, name, utilization, resets_in_minutes, resets_at=None):
        self.name = name
        self.utilization = utilization
        self.resets_in_minutes = resets_in_minutes
        self.resets_at = resets_at
