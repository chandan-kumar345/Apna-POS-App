/// Customer labels are separate from POS status: accepting a QR order uses
/// "preparing" internally before its first KOT has actually been sent.
enum CustomerOrderStatus {
  pending('Awaiting acceptance', 0),
  confirmed('Confirmed', 0),
  preparing('Preparing', 1),
  ready('Ready to serve', 2),
  completed('Completed', 3),
  cancelled('Cancelled', -1);

  final String label;
  final int step;
  const CustomerOrderStatus(this.label, this.step);

  static CustomerOrderStatus resolve(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final details = data['whatsappDetails'];
    final acceptance =
        (data['acceptanceStatus'] ??
                data['whatsappStatus'] ??
                (details is Map ? details['acceptanceStatus'] : null) ??
                '')
            .toString()
            .toLowerCase();
    if (['cancelled', 'canceled', 'rejected', 'declined'].contains(status) ||
        acceptance == 'rejected') {
      return cancelled;
    }
    if (['completed', 'delivered', 'settled', 'served'].contains(status)) {
      return completed;
    }
    if (['ready', 'out_for_delivery'].contains(status)) return ready;
    final kot = (data['kotStatus'] ?? '').toString().toLowerCase();
    if (['sent', 'printed', 'running', 'preparing'].contains(kot)) {
      return preparing;
    }
    if (['accepted', 'confirmed'].contains(status)) return confirmed;
    if (status == 'preparing') {
      return acceptance == 'accepted' ? confirmed : preparing;
    }
    if (acceptance == 'accepted') return confirmed;
    return pending;
  }
}
