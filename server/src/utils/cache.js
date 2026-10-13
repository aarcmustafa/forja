/**
 * ذاكرة مؤقتة بسيطة (in-memory)
 */
class SimpleCache {
  constructor(ttlMs = 30 * 60 * 1000) {
    // 30 دقيقة افتراضياً
    this.ttl = ttlMs;
    this.store = new Map();
  }

  get(key) {
    const entry = this.store.get(key);
    if (!entry) return null;

    if (Date.now() - entry.timestamp > this.ttl) {
      this.store.delete(key);
      return null;
    }

    return entry.value;
  }

  set(key, value) {
    this.store.set(key, {
      value,
      timestamp: Date.now(),
    });
  }

  has(key) {
    return this.get(key) !== null;
  }

  clear() {
    this.store.clear();
  }

  size() {
    return this.store.size;
  }
}

module.exports = SimpleCache;
