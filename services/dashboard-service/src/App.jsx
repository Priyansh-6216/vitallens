import React, { useState, useEffect } from 'react';
import RecoveryRing from './components/RecoveryRing';
import CSVUploader from './components/CSVUploader';
import WhoopConnector from './components/WhoopConnector';
import { 
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area 
} from 'recharts';
import { Sparkles, Activity, Moon, Heart, Zap, RefreshCw } from 'lucide-react';

const GATEWAY_URL = 'http://localhost:8080';

const App = () => {
  const [data, setData] = useState(null);
  const [recoveryData, setRecoveryData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [isConnected, setIsConnected] = useState(false);

  const fetchDashboardData = async () => {
    try {
      // 1. Fetch Today's Recovery from the new persistence layer
      const recResp = await fetch(`${GATEWAY_URL}/api/v1/recovery/today?userId=demo-user`);
      const recResult = await recResp.json();
      setRecoveryData(recResult);

      // 2. Fetch AI Insights
      const response = await fetch(`${GATEWAY_URL}/api/v1/ai/explain-recovery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user_id: "demo-user",
          day: new Date().toISOString().split('T')[0],
          recovery_score: recResult.recoveryScore || 0,
          hrv: recoveryData?.hrv || 65,
          rhr: recoveryData?.rhr || 58,
          sleep_duration_min: 450,
          sleep_debt_min: 0,
          alerts: recResult.topFactors || [],
          journal_factors: []
        })
      });
      const result = await response.json();
      setData(result);
    } catch (error) {
      console.error("Failed to fetch data", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // Check if we just returned from a successful connection
    const params = new URLSearchParams(window.location.search);
    if (params.get('connected') === 'true') {
      setIsConnected(true);
      // Clean up URL
      window.history.replaceState({}, document.title, "/");
    }

    fetchDashboardData();
  }, []);

  const handleRefresh = async () => {
    setSyncing(true);
    
    // If connected, trigger a server-side sync first
    if (isConnected) {
      try {
        await fetch(`${GATEWAY_URL}/api/v1/recovery/sync?userId=demo-user`, { method: 'POST' });
      } catch (e) {
        console.error("Sync failed", e);
      }
    }

    await fetchDashboardData();
    setSyncing(false);
  };

  const chartData = [
    { day: 'Mon', hrv: 58 },
    { day: 'Tue', hrv: 62 },
    { day: 'Wed', hrv: 60 },
    { day: 'Thu', hrv: 64 },
    { day: 'Fri', hrv: 62 },
    { day: 'Sat', hrv: 68 },
    { day: 'Sun', hrv: 65 },
  ];

  if (loading) return (
    <div className="dashboard-container" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
      <div className="loading">Initializing Neural Link...</div>
    </div>
  );

  return (
    <div className="dashboard-container">
      <header>
        <div className="logo">VITALLENS AI</div>
        <button 
          className="sync-button" 
          onClick={handleRefresh}
          disabled={syncing}
          style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}
        >
          <RefreshCw size={16} className={syncing ? 'spin' : ''} />
          {syncing ? 'Syncing...' : 'Refresh'}
        </button>
      </header>

      <div className="grid">
        {/* Left Column: Data Import & Recovery */}
        <div className="col-4">
          <WhoopConnector isConnected={isConnected} />
          <CSVUploader onUploadSuccess={handleRefresh} />
          
          <div className="glass-card">
            <h2 style={{ marginBottom: '1.5rem', opacity: 0.8 }}>Daily Readiness</h2>
            <RecoveryRing score={recoveryData?.recoveryScore || 0} />
            <div style={{ marginTop: '2rem', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              <div className="stat-box">
                <div className="score-label">Latest HRV</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{recoveryData?.hrv || 65} ms</div>
              </div>
              <div className="stat-box">
                <div className="score-label">RHR</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{recoveryData?.rhr || 58} bpm</div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: HRV Trends */}
        <div className="col-8 glass-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
            <h2 style={{ opacity: 0.8 }}>Recovery Trend (HRV)</h2>
            <Activity className="ai-icon" />
          </div>
          <div style={{ width: '100%', height: '340px' }}>
            <ResponsiveContainer>
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="colorHrv" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#00ff88" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#00ff88" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                <XAxis dataKey="day" stroke="#a0a6b1" axisLine={false} tickLine={false} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#1a1c20', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px' }}
                  itemStyle={{ color: '#00ff88' }}
                />
                <Area type="monotone" dataKey="hrv" stroke="#00ff88" fillOpacity={1} fill="url(#colorHrv)" strokeWidth={3} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Bottom Panel: AI COACH INSIGHTS */}
        <div className="col-12 glass-card ai-panel">
          <div className="ai-header">
            <Sparkles className="ai-icon" />
            <h2 style={{ fontWeight: 600 }}>AI Coach Insights</h2>
          </div>
          <div style={{ fontSize: '1.1rem', lineHeight: '1.6', opacity: 0.9 }}>
            {data?.summary || "Upload your data or connect WHOOP to get personalized AI coaching."}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.5rem', marginTop: '1.5rem' }}>
            {recoveryData?.topFactors?.map((rec, i) => (
              <div key={i} style={{ display: 'flex', gap: '1rem', alignItems: 'flex-start', background: 'rgba(255,255,255,0.03)', padding: '1rem', borderRadius: '16px' }}>
                <Zap size={18} style={{ color: '#00d2ff', marginTop: '3px' }} />
                <div>{rec}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default App;
