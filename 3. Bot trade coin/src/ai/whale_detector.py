import logging
from typing import List, Dict, Any
import numpy as np
from sklearn.ensemble import IsolationForest

logger = logging.getLogger("WhaleDetector")


class WhaleAnomalyDetector:
    """
    Isolation Forest anomaly detector for identifying abnormal whale accumulation or dumping.
    """

    def __init__(self):
        self.model = IsolationForest(contamination=0.05, random_state=42)
        self._is_fitted = False
        self._init_baseline()

    def _init_baseline(self) -> None:
        """Fit with standard baseline transaction distributions"""
        # Features: [amount, tx_frequency, pool_impact_pct]
        X_train = np.array([
            [10_000, 1, 0.01],
            [25_000, 2, 0.02],
            [50_000, 3, 0.05],
            [100_000, 2, 0.10],
            [200_000, 4, 0.20],
            [500_000, 5, 0.50],
            [1_000_000, 8, 1.00],
            [5_000_000, 12, 5.00],  # Outlier
        ])
        self.model.fit(X_train)
        self._is_fitted = True

    def detect_anomaly(self, amount: float, tx_frequency: int = 1, pool_impact_pct: float = 0.1) -> Dict[str, Any]:
        """
        Evaluate if a transaction is anomalous.
        Returns is_anomaly (True/False) and anomaly_score (negative = more anomalous).
        """
        X = np.array([[amount, tx_frequency, pool_impact_pct]])
        prediction = self.model.predict(X)[0]  # -1 for anomaly, 1 for normal
        score = float(self.model.decision_function(X)[0])

        is_anomaly = (prediction == -1) or (amount >= 500_000.0)
        return {
            "is_anomaly": is_anomaly,
            "anomaly_score": round(score, 3),
            "amount": amount,
            "level": "CRITICAL" if score < -0.1 else ("HIGH" if is_anomaly else "NORMAL"),
        }
