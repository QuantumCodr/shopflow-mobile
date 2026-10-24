/// Shared email-format validation for ShopFlow.
///
/// This checks the address structure only. It cannot verify that
/// a mailbox exists or that the current user owns that mailbox.
class EmailValidator {
  EmailValidator._();

  // Practical character checks for the part before @.
  static final RegExp _localPartPattern =
      RegExp(r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.-]+$");

  // Domain labels must not begin or end with a hyphen.
  static final RegExp _domainLabelPattern =
      RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$');

  static bool isValid(String value) {
    final email = value.trim();

    if (email.isEmpty || email.contains(RegExp(r'\s'))) {
      return false;
    }

    // An email must contain exactly one @, with text on both sides.
    final atIndex = email.indexOf('@');

    if (atIndex <= 0 ||
        atIndex != email.lastIndexOf('@') ||
        atIndex == email.length - 1) {
      return false;
    }

    final localPart = email.substring(0, atIndex);
    final domain = email.substring(atIndex + 1);

    // Practical checks for dots in the local part.
    if (localPart.length > 64 ||
        localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..')) {
      return false;
    }

    if (!_localPartPattern.hasMatch(localPart)) {
      return false;
    }

    // Require a dot-separated domain with no empty labels.
    if (domain.length > 253 || !domain.contains('.')) {
      return false;
    }

    final labels = domain.split('.');

    for (final label in labels) {
      if (label.isEmpty ||
          label.length > 63 ||
          !_domainLabelPattern.hasMatch(label)) {
        return false;
      }
    }

    return true;
  }
}