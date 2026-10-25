import 'package:flutter/material.dart';

import 'package:iconsax_plus/iconsax_plus.dart';

class FundingSponsor {
  final String name;
  final String platform;
  final String url;
  final Color? color;
  final IconData icon;

  const FundingSponsor({
    required this.name,
    required this.platform,
    required this.url,
    this.color,
    required this.icon,
  });
}

const sponsors = <FundingSponsor>[];

