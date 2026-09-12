import formatterTest from './Formatter.test';
import timeUtilTest from './TimeUtil.test';
import openCodeApiTest from './OpenCodeApi.test';
import syncManagerTest from './SyncManager.test';
import recordsFilterTest from './RecordsFilter.test';

export default function testsuite() {
  formatterTest();
  timeUtilTest();
  openCodeApiTest();
  syncManagerTest();
  recordsFilterTest();
}
