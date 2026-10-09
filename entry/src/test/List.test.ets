import formatterTest from './Formatter.test';
import timeUtilTest from './TimeUtil.test';
import openCodeApiTest from './OpenCodeApi.test';
import syncManagerTest from './SyncManager.test';
import recordsFilterTest from './RecordsFilter.test';
import quotaSourceTest from './QuotaSource.test';
import consoleSnapshotTest from './ConsoleSnapshot.test';
import consoleCsvTest from './ConsoleCsv.test';
import consoleIntradayTest from './ConsoleIntraday.test';
import consoleLogsTest from './ConsoleLogs.test';
import modelIconTest from './ModelIcon.test';
import themeUtilTest from './ThemeUtil.test';

export default function testsuite() {
  formatterTest();
  timeUtilTest();
  openCodeApiTest();
  syncManagerTest();
  recordsFilterTest();
  quotaSourceTest();
  consoleSnapshotTest();
  consoleCsvTest();
  consoleIntradayTest();
  consoleLogsTest();
  modelIconTest();
  themeUtilTest();
}
