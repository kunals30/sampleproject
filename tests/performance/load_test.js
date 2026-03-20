import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 5,
  duration: '10s',
  thresholds: {
    http_req_duration: ['p(95)<500'], // SLA: 95% < 500ms
  },
};

export default function () {
  let res = http.get('https://example.com');
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
  sleep(1);
}
