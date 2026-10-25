import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:newcalflix/models/items/photos_model.dart';
import 'package:newcalflix/models/syncing/sync_item.dart';
import 'package:newcalflix/providers/sync/sync_provider_helpers.dart';
import 'package:newcalflix/providers/sync_provider.dart';
import 'package:newcalflix/screens/shared/default_alert_dialog.dart';
import 'package:newcalflix/screens/shared/flat_button.dart';
import 'package:newcalflix/screens/syncing/sync_widgets.dart';
import 'package:newcalflix/theme.dart';
import 'package:newcalflix/util/fladder_image.dart';
import 'package:newcalflix/util/list_padding.dart';
import 'package:newcalflix/util/localization_helper.dart';
import 'package:newcalflix/util/size_formatting.dart';
import 'package:newcalflix/widgets/shared/icon_button_await.dart';

class SyncedPhotoItem extends ConsumerWidget {
  const SyncedPhotoItem({
    super.key,
    required this.photo,
    required this.syncedItem,
  });

  final PhotoModel photo;
  final SyncedItem syncedItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadTask = ref.watch(downloadTasksProvider(syncedItem.id));
    final hasFile = syncedItem.videoFile.existsSync();
    return Row(
      children: [
        FlatButton(
          onTap: () {
            photo.navigateTo(context);
            return context.maybePop();
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: FladderTheme.defaultPosterDecoration,
            clipBehavior: Clip.hardEdge,
            child: FladderImage(
              image: photo.thumbnail?.primary,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                photo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!hasFile && downloadTask.hasDownload)
                SyncProgressBar(item: syncedItem, task: downloadTask)
              else
                SyncLabel(
                  label: context.localized.totalSize(ref.watch(syncSizeProvider(syncedItem, [])).byteFormat ?? '--'),
                  status: ref.watch(syncDownloadStatusProvider(syncedItem, [])
                      .select((value) => value?.status ?? TaskStatus.notFound)),
                ),
            ],
          ),
        ),
        if (!hasFile && !downloadTask.hasDownload)
          IconButtonAwait(
            onPressed: () async => await ref.read(syncProvider.notifier).syncSyncedItem(context, syncedItem),
            icon: const Icon(IconsaxPlusLinear.import_3),
          )
        else if (hasFile)
          IconButtonAwait(
            color: Theme.of(context).colorScheme.error,
            onPressed: () async {
              await showDefaultAlertDialog(
                context,
                context.localized.syncRemoveDataTitle,
                context.localized.syncRemoveDataDesc,
                (context) async {
                  await ref.read(syncProvider.notifier).deleteFullSyncFiles(syncedItem, downloadTask.task);
                  Navigator.pop(context);
                },
                context.localized.delete,
                (context) => Navigator.pop(context),
                context.localized.cancel,
              );
            },
            icon: const Icon(IconsaxPlusLinear.trash),
          ),
      ].addInBetween(const SizedBox(width: 16)),
    );
  }
}

