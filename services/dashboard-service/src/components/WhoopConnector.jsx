import React from 'react';
import { ExternalLink, CheckCircle } from 'lucide-react';

const GATEWAY_URL = 'http://localhost:8080';

const WhoopConnector = ({ isConnected }) => {
  const handleConnect = () => {
    // Redirect to the backend OAuth initiation endpoint
    window.location.href = `${GATEWAY_URL}/api/v1/recovery/auth/connect?userId=demo-user`;
  };

  return (
    <div className="glass-card" style={{ marginBottom: '1.5rem', background: 'rgba(0, 210, 255, 0.05)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1rem' }}>
        <ExternalLink size={20} color="#00d2ff" />
        <h3 style={{ fontSize: '1.2rem', fontWeight: 600 }}>WHOOP Live Sync</h3>
      </div>
      
      <p style={{ color: '#a0a6b1', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
        Connect your WHOOP account to automatically sync recovery, HRV, and sleep data in real-time.
      </p>

      {!isConnected ? (
        <button 
          className="sync-button" 
          onClick={handleConnect}
          style={{ 
            background: '#00d2ff', 
            color: '#000', 
            fontWeight: 600,
            width: '100%',
            justifyContent: 'center' 
          }}
        >
          Connect WHOOP Account
        </button>
      ) : (
        <div style={{ 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'center', 
          gap: '0.5rem', 
          color: '#00ff88',
          padding: '0.8rem',
          background: 'rgba(0, 255, 136, 0.1)',
          borderRadius: '12px'
        }}>
          <CheckCircle size={18} />
          <span style={{ fontWeight: 600 }}>WHOOP Connected</span>
        </div>
      )}
    </div>
  );
};

export default WhoopConnector;
