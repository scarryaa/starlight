import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:starlight/features/file_explorer/domain/models/git_status.dart';

class GitService {
  Future<Map<String, GitStatus>> getDirectoryGitStatus(
      String directoryPath) async {
    final result = <String, GitStatus>{};
    try {
      final gitStatusProcess = await Process.run(
        'git',
        ['status', '--porcelain', '-uall'],
        workingDirectory: directoryPath,
      );

      if (gitStatusProcess.exitCode == 0) {
        final lines = gitStatusProcess.stdout.toString().split('\n');
        for (var line in lines) {
          if (line.isNotEmpty) {
            final status = line.substring(0, 2).trim();
            final filePath = line.substring(3);
            result[filePath] = _parseGitStatus(status);

            // Update parent directories
            var parentDir = path.dirname(filePath);
            while (parentDir != '.' && parentDir != directoryPath) {
              result[parentDir] = GitStatus.modified;
              parentDir = path.dirname(parentDir);
            }
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
