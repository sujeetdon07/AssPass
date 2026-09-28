import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../messaging/domain/repositories/messaging_repository.dart';

/// Screen displaying a neighbor's public profile resolved by their unique @username.
class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.username,
  });

  final String username;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  UserEntity? _user;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isStartingChat = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .getUserByUsername(widget.username);

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not find user @${widget.username.replaceAll('@', '')}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startConversation(UserEntity user) async {
    setState(() {
      _isStartingChat = true;
    });

    try {
      final conv = await ref
          .read(messagingRepositoryProvider)
          .createOrGetConversation(user.id);

      if (mounted) {
        context.push('/messages/${conv.id}');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Unable to start conversation: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingChat = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;

    final isOwnProfile = _user != null && _user!.id == currentUserId;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.arrowBack,
          semanticLabel: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Text(
          widget.username.startsWith('@')
              ? widget.username
              : '@${widget.username}',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_user != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share Profile',
              onPressed: () {
                final payload = AppShareService.buildProfilePayload(
                  displayName: _user!.displayName ?? 'Neighbor',
                  username: _user!.username,
                  locality: _user!.localitySummary,
                );
                AppShareService.share(context, payload);
              },
            ),
        ],
      ),
      body: _buildBody(context, isDark, isOwnProfile),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, bool isOwnProfile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _user == null) {
      return Center(
        child: AppErrorState(
          message: _errorMessage ?? 'User not found.',
          onRetry: _loadProfile,
        ),
      );
    }

    final user = _user!;
    final displayName = user.displayName ?? 'Neighbor';
    final handle = user.handle ?? '@${widget.username.replaceAll('@', '')}';
    final locality = user.localitySummary;

    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            AppSpacing.gapVSm,

            // Profile Overview Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppAvatar(
                        imageUrl: user.avatarUrl,
                        name: displayName,
                        size: AppAvatarSize.s72,
                        semanticLabel: '$displayName avatar',
                      ),
                      AppSpacing.gapHMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppSpacing.gapVXs,
                            Text(
                              handle,
                              style: AppTypography.titleSmall.copyWith(
                                color: isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            AppSpacing.gapVXs,
                            Row(
                              children: [
                                Icon(
                                  AppIcons.location,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.darkPrimary
                                      : AppColors.lightPrimary,
                                ),
                                AppSpacing.gapHXs,
                                Flexible(
                                  child: Text(
                                    locality,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (user.neighborhood != null &&
                      user.neighborhood!.trim().isNotEmpty) ...[
                    AppSpacing.gapVSm,
                    Text(
                      user.neighborhood!.trim(),
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                    AppSpacing.gapVMd,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                        borderRadius: AppRadius.card,
                      ),
                      child: Text(
                        user.bio!.trim(),
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  AppSpacing.gapVLg,

                  // Action Buttons
                  if (isOwnProfile)
                    AppButton(
                      text: 'Edit Profile',
                      variant: AppButtonVariant.outlined,
                      prefixIcon: AppIcons.edit,
                      onPressed: () => context.push(AppRoutes.editProfile),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Message',
                            variant: AppButtonVariant.primary,
                            prefixIcon: Icons.chat_bubble_outline_rounded,
                            isLoading: _isStartingChat,
                            onPressed: () => _startConversation(user),
                          ),
                        ),
                        AppSpacing.gapHSm,
                        AppButton(
                          isFullWidth: false,
                          text: 'Share',
                          variant: AppButtonVariant.outlined,
                          prefixIcon: Icons.share_rounded,
                          onPressed: () {
                            final payload = AppShareService.buildProfilePayload(
                              displayName: displayName,
                              username: user.username,
                              locality: locality,
                            );
                            AppShareService.share(context, payload);
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
