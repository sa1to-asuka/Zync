import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/download_manager.dart';

void main() {
  group('传输保活状态机 transferKeepAliveState', () {
    test('队列为空（含暂停状态）不启动保活', () {
      expect(
        transferKeepAliveState(queued: 0, downloading: 0, paused: false),
        TransferKeepAliveState.none,
      );
      expect(
        transferKeepAliveState(queued: 0, downloading: 0, paused: true),
        TransferKeepAliveState.none,
      );
    });

    test('有排队或下载中的任务即保活', () {
      expect(
        transferKeepAliveState(queued: 3, downloading: 0, paused: false),
        TransferKeepAliveState.active,
      );
      expect(
        transferKeepAliveState(queued: 0, downloading: 1, paused: false),
        TransferKeepAliveState.active,
      );
    });

    test('暂停时通知切换为已暂停，但仍保持保活', () {
      expect(
        transferKeepAliveState(queued: 3, downloading: 0, paused: true),
        TransferKeepAliveState.paused,
      );
      expect(
        transferKeepAliveState(queued: 0, downloading: 1, paused: true),
        TransferKeepAliveState.paused,
      );
    });
  });
}
