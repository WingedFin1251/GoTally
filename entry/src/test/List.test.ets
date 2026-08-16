import formatterTest from './Formatter.test';
import timeUtilTest from './TimeUtil.test';
import openCodeApiTest from './OpenCodeApi.test';

export default function testsuite() {
  formatterTest();
  timeUtilTest();
  openCodeApiTest();
}
