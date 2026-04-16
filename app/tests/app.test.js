const request = require('supertest');
const app = require('../index');

describe('GET /', () => {
  it('returns status ok and version', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body).toHaveProperty('version');
  });
});

describe('GET /health', () => {
  it('returns healthy status and uptime', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body).toHaveProperty('uptime');
  });
});

describe('GET /greet/:name', () => {
  it('greets a valid name', async () => {
    const res = await request(app).get('/greet/Eagle');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello, Eagle!');
  });

  it('returns 404 for missing name segment', async () => {
    const res = await request(app).get('/greet/');
    expect(res.statusCode).toBe(404);
  });
});
