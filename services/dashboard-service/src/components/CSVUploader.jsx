import React, { useState } from 'react';
import { Upload, FileText, CheckCircle, AlertCircle } from 'lucide-react';

const GATEWAY_URL = 'http://localhost:8080';

const CSVUploader = ({ onUploadSuccess }) => {
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [status, setStatus] = useState(null); // 'success', 'error'

  const handleFileChange = (e) => {
    setFile(e.target.files[0]);
    setStatus(null);
  };

  const handleUpload = async () => {
    if (!file) return;

    setUploading(true);
    const formData = new FormData();
    formData.append('file', file);
    formData.append('userId', 'demo-user');

    try {
      const response = await fetch(`${GATEWAY_URL}/api/v1/recovery/import`, {
        method: 'POST',
        body: formData,
      });

      if (response.ok) {
        setStatus('success');
        if (onUploadSuccess) onUploadSuccess();
      } else {
        setStatus('error');
      }
    } catch (error) {
      console.error("Upload failed", error);
      setStatus('error');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="glass-card" style={{ marginBottom: '1.5rem' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1rem' }}>
        <Upload size={20} color="#00ff88" />
        <h3 style={{ fontSize: '1.2rem', fontWeight: 600 }}>Connect Your Data</h3>
      </div>
      
      <p style={{ color: '#a0a6b1', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
        Upload your WHOOP <strong>physiological_cycles.csv</strong> to see real health insights.
      </p>

      <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
        <label className="sync-button" style={{ display: 'inline-block', cursor: 'pointer' }}>
          <input type="file" accept=".csv" style={{ display: 'none' }} onChange={handleFileChange} />
          {file ? 'Change File' : 'Select CSV'}
        </label>

        {file && (
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#00d2ff' }}>
            <FileText size={16} />
            <span style={{ fontSize: '0.9rem' }}>{file.name}</span>
          </div>
        )}

        {file && !uploading && !status && (
          <button className="sync-button" onClick={handleUpload} style={{ background: '#00ff88', color: '#000' }}>
            Upload
          </button>
        )}
      </div>

      {uploading && <div style={{ marginTop: '1rem', color: '#00ff88' }}>Analyzing data streams...</div>}

      {status === 'success' && (
        <div style={{ marginTop: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#00ff88' }}>
          <CheckCircle size={16} />
          <span>Data synced successfully! refresh to see changes.</span>
        </div>
      )}

      {status === 'error' && (
        <div style={{ marginTop: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#ff4b4b' }}>
          <AlertCircle size={16} />
          <span>Upload failed. Check file format.</span>
        </div>
      )}
    </div>
  );
};

export default CSVUploader;
