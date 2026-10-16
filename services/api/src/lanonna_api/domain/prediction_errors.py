"""Fun prediction votes close when the baby is born."""

from lanonna_api.domain.fun_closed import ensure_fun_writes_open, fun_writes_closed


class PredictionsClosedError(Exception):
    """Gender and birthdate votes cannot be created or changed."""

    code = "predictions_closed"

    def __init__(self) -> None:
        self.message = "Predictions closed — baby has arrived"
        super().__init__(self.message)


def ensure_predictions_open(membership: dict[str, object]) -> None:
    if fun_writes_closed(membership):
        raise PredictionsClosedError()
