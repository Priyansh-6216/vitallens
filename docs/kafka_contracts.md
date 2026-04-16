# Kafka Event Contracts

VitalLens AI uses a schema-first approach for event-driven communication. All events are serialized as JSON (or Avro in production) and follow a standardized structure.

## Topic 1: `wearable.data.received`
Published by the **Device Integration Service** when new data is pulled from a provider (WHOOP, Garmin, etc.).

### Schema
```json
{
  "eventId": "uuid",
  "timestamp": "iso-8601",
  "userId": "uuid",
  "provider": "string",
  "payloadType": "string", // e.g., "sleep", "recovery", "activity"
  "rawData": {} // Raw provider payload
}
```

## Topic 2: `metrics.ingested`
Published by the **Metric Ingestion Service** after normalizing and storing biometric samples.

### Schema
```json
{
  "userId": "uuid",
  "metricType": "string", // "hrv", "rhr", "respiratory_rate"
  "value": "float",
  "unit": "string",
  "recordedAt": "iso-8601"
}
```

## Topic 3: `recovery.calculated`
Published by the **Recovery Service** after computing the daily readiness score.

### Schema
```json
{
  "userId": "uuid",
  "day": "YYYY-MM-DD",
  "recoveryScore": "int",
  "readinessBand": "string",
  "contributingFactors": [
    "string"
  ],
  "hrv": "float",
  "rhr": "float"
}
```

## Topic 4: `recommendation.generate`
Published to trigger the **AI Coach Service** to produce a user-facing narrative.

### Schema
```json
{
  "userId": "uuid",
  "context": {
    "day": "YYYY-MM-DD",
    "recoveryScore": 46,
    "sleepLevel": "low",
    "recentStrain": 15.2,
    "anomalies": ["elevated_rhr"]
  }
}
```

## Topic 5: `notification.send`
Published to the **Notification Service** for final delivery to the user via push/email.

### Schema
```json
{
  "userId": "uuid",
  "type": "PUSH",
  "title": "Your Morning Recovery is Ready",
  "body": "You scored 46% today. The AI suggests a light recovery session.",
  "metadata": {
    "actionLink": "/app/recovery/today"
  }
}
```
