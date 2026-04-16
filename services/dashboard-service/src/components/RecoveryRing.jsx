import React from 'react';

const RecoveryRing = ({ score }) => {
  const radius = 85;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (score / 100) * circumference;

  return (
    <div className="recovery-ring-container">
      <svg className="recovery-svg" width="200" height="200">
        <circle
          className="recovery-bg"
          cx="100"
          cy="100"
          r={radius}
        />
        <circle
          className="recovery-progress"
          cx="100"
          cy="100"
          r={radius}
          style={{
            strokeDasharray: circumference,
            strokeDashoffset: offset
          }}
        />
      </svg>
      <div className="recovery-score">
        <div className="score-value">{score}</div>
        <div className="score-label">Recovery</div>
      </div>
    </div>
  );
};

export default RecoveryRing;
