/// Shown for any network-unreachable failure — the one shared copy for
/// this case across the whole app.
const kNetworkFailureMessage =
    "Couldn't reach Tadarab. Check your connection and try again.";

/// Shown for any other failure that isn't one of the more specific cases
/// a feature defines for itself — the one shared copy for this case, same
/// callers as [kNetworkFailureMessage].
const kGenericFailureMessage = 'Something went wrong. Please try again.';
