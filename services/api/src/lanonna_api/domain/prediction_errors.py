"""Fun prediction votes close when the baby is born."""


class PredictionsClosedError(Exception):
    """Gender and birthdate votes cannot be created or changed."""

    code = "predictions_closed"

    def __init__(self) -> None:
        self.message = "Predictions closed — baby has arrived"
        super().__init__(self.message)
