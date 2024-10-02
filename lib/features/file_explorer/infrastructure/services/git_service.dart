import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:starlight/features/file_explorer/domain/models/git_status.dart';

class GitService extends ChangeNotifier {
  final ValueNotifier<String> currentBranch = ValueNotifier<String>('');
  List<String> branches = [];

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

  Future<void> fetchBranches(String directoryPath) async {
    try {
      final gitBranchProcess = await Process.run(
        'git',
        ['branch'],
        workingDirectory: directoryPath,
      );
      if (gitBranchProcess.exitCode == 0) {
        branches = gitBranchProcess.stdout
            .toString()
            .split('\n')
            .where((branch) => branch.isNotEmpty)
            .map((branch) => branch.trim().replaceFirst('* ', ''))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching git branches: $e');
    }
  }

  Future<void> switchBranch(String branch, String directoryPath) async {
    try {
      final gitCheckoutProcess = await Process.run(
        'git',
        ['checkout', branch],
        workingDirectory: directoryPath,
      );
      if (gitCheckoutProcess.exitCode == 0) {
        currentBranch.value = branch;
        notifyListeners();
      } else {
        print('Error switching branch: ${gitCheckoutProcess.stderr}');
      }
    } catch (e) {
      print('Error switching git branch: $e');
    }
  }

  Future<void> getCurrentBranch(String directoryPath) async {
    try {
      final gitBranchProcess = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: directoryPath,
      );
      if (gitBranchProcess.exitCode == 0) {
        currentBranch.value = gitBranchProcess.stdout.toString().trim();
        notifyListeners();
      }
    } catch (e) {
      print('Error getting current git branch: $e');
    }
  }
}
