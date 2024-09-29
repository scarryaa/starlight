import 'dart:io';
import 'package:starlight/features/file_explorer/domain/models/git_status.dart';

class GitService {
  Future<Map<String, GitStatus>> getDirectoryGitStatus(String path) async {
    final result = <String, GitStatus>{};
    try {
      final gitStatusProcess = await Process.run(
          'git', ['status', '--porcelain'],
          workingDirectory: path);

      if (gitStatusProcess.exitCode == 0) {
        final lines = gitStatusProcess.stdout.toString().split('\n');
        for (var line in lines) {
          if (line.isNotEmpty) {
            final status = line.substring(0, 2).trim();
            final filePath = line.substring(3);
            result[filePath] = _parseGitStatus(status);
          }
        }
      }
    } catch (e) {
      print('Error getting git status: $e');
    }

    return result;
  }

  GitStatus _parseGitStatus(String status) {
    switch (status) {
      case 'M':
        return GitStatus.modified;
      case 'A':
        return GitStatus.added;
      case 'D':
        return GitStatus.deleted;
      case 'R':
        return GitStatus.renamed;
      case '??':
        return GitStatus.untracked;
      default:
        return GitStatus.none;
    }
  }
}
