import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/model/CarogDetails_model.dart';
import 'package:Auras/model/DRecommendation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:open_file/open_file.dart';

Future<void> generateTowagePdfWithHeader({
  required String jobNumber,
  required String certificateNumber,
  required String projectTitle,
  required String clientName,
  required String towName,
  required String tugName,
  required String cargo,
  required String fromPort,
  required String toPort,
  required String HeaderImagePath,
  required String CertificateType,
  required bool isCargoDetailsNA,
  required bool includeAnnexure2,
  required String surveyedBy,
  Uint8List? stampBytes,

  Uint8List? clientBytes,
  List<CargoDetail>? cargoDetails,
  List<DefaultRecommendation>? recommendations,
  Uint8List? signatureBytes,
  required String issuedDate,
  required int certificateId,
  List<CargoDetail>? cargoDetail,
}) async {
  List<CargoDetail> finalCargoDetails = [];
  if (certificateId != 0) {
    finalCargoDetails = await DatabaseHelper().getCargoDetails(certificateId);
  } else if (cargoDetails != null) {
    finalCargoDetails = cargoDetails;
  }

  final document = sf.PdfDocument();
  final page = document.pages.add();
  final graphics = page.graphics;

  final boldFont = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    8,
    style: sf.PdfFontStyle.bold,
  );
  final normalFont = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 13);
  final titleFont = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    8,
    style: sf.PdfFontStyle.bold,
  );
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final double pageWidth = page.getClientSize().width;
  final double pageHeight = page.getClientSize().height;
  const double margin = 15;
  final double contentWidth = pageWidth - 2 * margin;
  double y = margin;

  const double borderMargin = 2; // ~0.5 cm from edge
  graphics.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 2.0),
    bounds: Rect.fromLTWH(
      borderMargin,
      borderMargin,
      pageWidth - 2 * borderMargin,
      pageHeight - 2 * borderMargin,
    ),
  );

  double cmToPt = 28.35;
  double innerMargin = 2.0 * cmToPt; // ≈ 2 cm each side
  double top = innerMargin;
  double left = innerMargin;
  double right = page.getClientSize().width - innerMargin;
  double bottom = page.getClientSize().height - innerMargin;

  // Reserve footer space
  double footerReserve = 85;
  double usableHeightForBody = (bottom - top) - footerReserve;

  Future<List<String>> fetchRecommendationsFromDB(int certificateId) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'default_recommendations',
      where: 'certificateId = ?',
      whereArgs: [certificateId],
    );
    return result.map((e) => e['recommendationText'] as String).toList();
  }

  try {
    final imageData = await rootBundle.load(HeaderImagePath);
    final headerImage = sf.PdfBitmap(imageData.buffer.asUint8List());

    // 🖼️ Adjust header image size
    // Left = margin - 6 (same)
    // Top = y - 8 (same)
    // Width increased from 530 → 560
    // Height increased from 30 → 45
    graphics.drawImage(
      headerImage,
      Rect.fromLTWH(
        margin - 6, // x-position
        y - 8, // y-position
        500, // ⬅️ wider
        40, // ⬆️ taller
      ),
    );

    // Adjust Y offset for the new image height
    y += 55; // previously 40, now more spacing
  } catch (_) {
    graphics.drawString(
      "",
      normalFont,
      bounds: Rect.fromLTWH(margin, y, 300, 20),
    );
    y += 25;
  }

  y += 5;
  graphics.drawString(
    '$jobNumber / $certificateNumber',
    boldFont,

    // 👇 move 10 pts left
    bounds: Rect.fromLTWH(margin - 20, y, contentWidth, 20),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
  );
  y += 20;

  // Create a larger font for the title
  final largeTitleFont = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    14,
    style: sf.PdfFontStyle.bold,
  );

  // Draw the title with larger font
  graphics.drawString(
    'CERTIFICATE OF APPROVAL - TOWAGE',
    largeTitleFont, // 👈 use the new bigger font
    bounds: Rect.fromLTWH(margin, y, contentWidth, 30), // slightly taller box
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
  );

  y += 25;

  final grid = sf.PdfGrid();
  grid.columns.add(count: 2);
  final details = {
    'PROJECT': projectTitle,
    'CLIENT': clientName,
    'NAME OF TOW': towName,
    'FROM LOCATION': fromPort,
    'TO LOCATION': toPort,
    'NAME OF TUG': tugName,
    'CARGO': cargo,
  };
  details.forEach((k, v) {
    final row = grid.rows.add();
    row.cells[0].value = k;
    row.cells[1].value = v;
    row.cells[0].style.backgroundBrush = sf.PdfBrushes.lightGray;
    row.cells[0].style.font = boldFont;
    row.cells[1].style.font = normalFont;
  });
  grid.style = sf.PdfGridStyle(
    cellPadding: sf.PdfPaddings(left: 3, top: 2, right: 3, bottom: 2),
  );
  final tableResult = grid.draw(
    page: page,
    bounds: Rect.fromLTWH(margin + 15, y, 480, 0),
  )!;
  y = tableResult.bounds.bottom + 6;

  const double sidePadding = 16; // Adjust side padding for narrower paragraph
  final double paragraphX = margin + sidePadding;
  final double paragraphWidth = contentWidth - 2 * sidePadding;
  y += 5;
  // Make a smaller font for paragraph
  final smallFont = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 10);

  // Then use it in the paragraph
  final paragraphText = sf.PdfTextElement(
    text:
        "This is to certify that this office represented by the undersigned, acting on request of $clientName, has inspected the above combination and confirms that it has been prepared for the above towage.\n\n"
        "The tug, tow and towing arrangements for the proposed voyage are approved subject to satisfactory compliance with the attached recommendations (Annexure-1).\n\n"
        "Departure from $fromPort shall take place only with the specific agreement of the undersigned or his nominated deputy, following submission of the favorable 48 hrs weather forecast and close-out of the annexed recommendations.\n\n"
        "This certificate of Approval is issued subject to $CertificateType Terms and Conditions of Business, current at the time of issue, without prejudice to any insurance interests or to any or all parties concerned. Any alterations in the surveyed items or deviations from the agreed procedures after issue of this Certificate may render the Certificate invalid unless specifically approved by this office.",
    font: smallFont, // 👈 use smaller font here
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.justify,
      lineAlignment: sf.PdfVerticalAlignment.top,
    ),
  );

  // Draw paragraph
  final paraResult = paragraphText.draw(
    page: page,
    bounds: Rect.fromLTWH(paragraphX, y, paragraphWidth, pageHeight - y - 80),
  )!;

  y = paraResult.bounds.bottom + 20;

  // --- Stamp ---
  const double stampLeftIndent = 30;
  if (stampBytes != null) {
    final stampImage = sf.PdfBitmap(stampBytes);
    graphics.drawImage(
      stampImage,
      Rect.fromLTWH(margin + stampLeftIndent, y, 50, 50),
    );
    y += 60;
  }

  // --- Signature Section ---
  const double indent = 18;
  graphics.drawString(
    "For and on behalf of",
    normalFont,
    bounds: Rect.fromLTWH(margin + indent, y, contentWidth - indent * 2, 20),
  );
  y += 18;

  graphics.drawString(
    CertificateType,
    boldFont,
    bounds: Rect.fromLTWH(margin + indent, y, contentWidth - indent * 2, 20),
  );
  y += 25;

  // --- Responsibility Table ---
  final page1Table = buildResponsibilityTable(
    surveyedBy: surveyedBy,
    issuedDate: issuedDate,
    signatureBytes: signatureBytes,
    boldFont: boldFont,
  );

  // ✅ Create Times Roman fonts
  final timesNormal = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 10);
  final timesBold = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    10,
    style: sf.PdfFontStyle.bold,
  );

  // --- Apply Times Roman to all rows ---
  for (int i = 0; i < page1Table.rows.count; i++) {
    final row = page1Table.rows[i];
    for (int j = 0; j < row.cells.count; j++) {
      row.cells[j].style.font = timesNormal;
    }
  }

  // --- Apply Times Roman to header (if any) ---
  if (page1Table.headers.count > 0) {
    for (int h = 0; h < page1Table.headers.count; h++) {
      final headerRow = page1Table.headers[h];
      for (int j = 0; j < headerRow.cells.count; j++) {
        headerRow.cells[j].style.font = timesBold;
      }
    }
  }

  // --- Estimate available height ---
  final double remainingHeight = pageHeight - y - 120;
  final double estimatedTableHeight = page1Table.rows.count * 25;

  sf.PdfPage targetPage = page;
  sf.PdfGraphics targetGraphics = graphics;

  // --- Add new page if table doesn't fit ---
  if (estimatedTableHeight > remainingHeight) {
    targetPage = document.pages.add();
    targetGraphics = targetPage.graphics;

    // Draw border around the new page
    targetGraphics.drawRectangle(
      bounds: Rect.fromLTWH(
        margin,
        margin,
        contentWidth,
        pageHeight - (2 * margin),
      ),
      pen: sf.PdfPen(sf.PdfColor(0, 0, 0)),
    );

    y = pageHeight - 85;
  } else {
    y = pageHeight - 85;
  }

  // --- Draw Responsibility Table (Times Roman) ---
  page1Table.draw(
    page: targetPage,
    bounds: Rect.fromLTWH(margin + 25, pageHeight - 85, contentWidth - 30, 0),
  );

  ///////////////////////////////////////////////////////////////////////////////////////////////

  // ➤ Add ANNEXURE Page
  final annexurePage = document.pages.add();
  final annexureGraphics = annexurePage.graphics;
  final annexureWidth = annexurePage.getClientSize().width;
  final annexureHeight = annexurePage.getClientSize().height;

  annexureGraphics.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      margin - 10,
      margin - 10,
      annexureWidth - (margin - 10) * 2,
      annexureHeight - (margin - 10) * 2,
    ),
  );
  // Draw Recommendation Heading
  annexureGraphics.drawString(
    "ANNEXURE-1 RECOMMENDATIONS TO CERTIFICATE OF APPROVAL",
    boldFont,
    bounds: Rect.fromLTWH(0, 30, annexureWidth, 25),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
  );

  annexureGraphics.drawString(
    "$jobNumber/$certificateNumber",
    boldFont,
    bounds: Rect.fromLTWH(0, 55, annexureWidth, 20),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
  );

  // Prepare Recommendation Table
  List<DefaultRecommendation> finalRecommendations = [];

  // ✅ Unified logic for both preview & generate
  if (certificateId != 0) {
    // Generate mode → fetch from DB
    final recStrings = await fetchRecommendationsFromDB(
      certificateId,
    ); // List<String>
    finalRecommendations = recStrings
        .map(
          (text) => DefaultRecommendation(id: null, recommendationText: text),
        )
        .toList();
  } else if (recommendations != null && recommendations.isNotEmpty) {
    // Preview mode → use passed-in list
    finalRecommendations = recommendations;
  }

  // // ❌ If still empty, use default recommendations (so PDF never shows blank)
  // if (finalRecommendations.isEmpty) {
  //   finalRecommendations = DefaultRecommendation
  //       .map(
  //         (text) => DefaultRecommendation(id: null, recommendationText: text),
  //       )
  //       .toList();
  // }
  final recommendationTable = sf.PdfGrid();
  recommendationTable.columns.add(count: 2);
  recommendationTable.columns[0].width = 40;
  recommendationTable.columns[1].width = annexureWidth - 2 * margin - 40 - 15;

  // Add Header
  final headerRow = recommendationTable.headers.add(1)[0];
  headerRow.cells[0].value = "SL. NO.";
  headerRow.cells[1].value = "Recommendations to be completed prior departure";

  for (int i = 0; i < headerRow.cells.count; i++) {
    final cell = headerRow.cells[i];
    cell.style.font = sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      12,
      style: sf.PdfFontStyle.bold,
    );
    cell.style.backgroundBrush = sf.PdfBrushes.lightGray;
    cell.style.stringFormat = sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.center,
      lineAlignment: sf.PdfVerticalAlignment.middle,
    );
  }
  // Add Rows
  final cellFont = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 11);

  // ✅ Use finalRecommendations instead of recommendations to avoid null issues
  for (int i = 0; i < (finalRecommendations.length); i++) {
    final row = recommendationTable.rows.add();
    row.cells[0].value = "${i + 1}";
    row.cells[1].value = finalRecommendations[i].recommendationText;
    row.height = 30;

    for (int j = 0; j < row.cells.count; j++) {
      row.cells[j].style.font = cellFont;
      row.cells[j].style.stringFormat = sf.PdfStringFormat(
        alignment: j == 0
            ? sf.PdfTextAlignment.center
            : sf.PdfTextAlignment.left,
        lineAlignment: sf.PdfVerticalAlignment.middle,
      );
    }
  }

  // Draw Table
  const double rightShift = 5;
  final sf.PdfLayoutResult recTableResult = recommendationTable.draw(
    page: annexurePage,
    bounds: Rect.fromLTWH(
      margin + rightShift,
      85,
      annexureWidth - 2 * margin - rightShift,
      0,
    ),
  )!;

  double annexureY = recTableResult.bounds.bottom + 20;

  // Estimate space required for footer block
  const double footerBlockHeight =
      50 + 18 + 25 + 85; // stamp + 2 lines + responsibility table
  final double remainingSpace = annexureHeight - annexureY;

  // Decide whether to draw footer on same page or new one
  sf.PdfPage footerPage = annexurePage;
  double footerY = annexureY;

  if (remainingSpace < footerBlockHeight) {
    footerPage = document.pages.add();

    // Draw border rectangle
    footerPage.graphics.drawRectangle(
      pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
      bounds: Rect.fromLTWH(
        margin - 10,
        margin - 10,
        annexureWidth - (margin - 10) * 2,
        annexureHeight - (margin - 10) * 2,
      ),
    );

    footerY = annexureHeight - footerBlockHeight + 5;
  }

  // ➤ Start with Stamp (left-aligned above text)
  const double stampWidth = 50;
  const double stampHeight = 50;
  double stampX = margin + 25; // adjust margin as needed

  if (stampBytes != null) {
    final sf.PdfBitmap stampImage = sf.PdfBitmap(stampBytes);
    footerPage.graphics.drawImage(
      stampImage,
      Rect.fromLTWH(stampX, footerY, stampWidth, stampHeight),
    );
    footerY += stampHeight + 10; // ⬅️ Reduced spacing to move everything up
  }

  // ➤ Draw "For and on behalf of" below the stamp
  footerPage.graphics.drawString(
    'For and on behalf of',
    normalFont,
    bounds: Rect.fromLTWH(margin + 25, footerY, pageWidth - 2 * margin, 15),
  );

  // ➤ Draw CertificateType (e.g. ARIES OIL FIELD SERVICES L.L.C)
  footerPage.graphics.drawString(
    CertificateType,
    boldFont,
    bounds: Rect.fromLTWH(
      margin + 25,
      footerY + 15,
      pageWidth - 2 * margin,
      20,
    ),
  );

  // ➤ Move footerY down for Responsibility Table
  footerY += 40;

  // ➤ Responsibility Table
  final annexureResponsibility = buildResponsibilityTable(
    surveyedBy: surveyedBy,
    issuedDate: issuedDate,
    signatureBytes: signatureBytes,
    boldFont: boldFont,
  );

  // --- Apply Times Roman to headers (if any) ---
  if (annexureResponsibility.headers.count > 0) {
    for (int h = 0; h < annexureResponsibility.headers.count; h++) {
      final headerRow = annexureResponsibility.headers[h];
      for (int j = 0; j < headerRow.cells.count; j++) {
        headerRow.cells[j].style.font = timesBold;
      }
    }
  }

  // --- Apply Times Roman to all body rows ---
  for (int i = 0; i < annexureResponsibility.rows.count; i++) {
    final row = annexureResponsibility.rows[i];
    for (int j = 0; j < row.cells.count; j++) {
      row.cells[j].style.font = timesNormal;
    }
  }

  // --- Draw the table ---
  annexureResponsibility.draw(
    page: footerPage,
    bounds: Rect.fromLTWH(margin + 25, footerY, annexureWidth - 50, 0),
  );

  // --- Cargo page section remains unchanged ---
  if (!isCargoDetailsNA) {
    final cargoPage = document.pages.add();
    final cargoGraphics = cargoPage.graphics;

    final cargoWidth = cargoPage.getClientSize().width;
    final cargoHeight = cargoPage.getClientSize().height;

    const double margin = 15;
    double y = margin;

    // ➤ Draw border
    cargoGraphics.drawRectangle(
      pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
      bounds: Rect.fromLTWH(
        margin - 10,
        margin - 10,
        cargoWidth - (margin - 10) * 2,
        cargoHeight - (margin - 10) * 2,
      ),
    );

    // ➤ Title
    cargoGraphics.drawString(
      "ANNEXURE-2 CARGO DETAILS",
      boldFont,
      bounds: Rect.fromLTWH(0, y + 15, cargoWidth, 20),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );

    // ➤ Certificate Number
    cargoGraphics.drawString(
      "$jobNumber/$certificateNumber",
      boldFont,
      bounds: Rect.fromLTWH(0, y + 35, cargoWidth, 20),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );

    // ➤ Subtitle
    cargoGraphics.drawString(
      "CARGO DETAILS",
      boldFont,
      bounds: Rect.fromLTWH(0, y + 60, cargoWidth, 20),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );

    // ➤ Prepare Cargo Table
    final cargoTable = sf.PdfGrid();
    cargoTable.columns.add(count: 7);

    final headerRow = cargoTable.headers.add(1)[0];
    const headers = [
      "Sr. No.",
      "Location",
      "Cargo",
      "ID markings",
      "Weight",
      "Dimensions",
      "Remarks",
    ];

    for (int i = 0; i < headers.length; i++) {
      headerRow.cells[i].value = headers[i];
      headerRow.cells[i].style
        ..font = boldFont
        ..backgroundBrush = sf.PdfBrushes.lightGray
        ..stringFormat = sf.PdfStringFormat(
          alignment: sf.PdfTextAlignment.center,
        );
    }

    // ➤ Fetch cargo details
    final cargoDetails = await DatabaseHelper().getCargoDetails(certificateId);
    int currentRowIndex = 0;

    for (final c in finalCargoDetails) {
      final row = cargoTable.rows.add();
      row.cells[0].value = "${++currentRowIndex}".padLeft(2, '0');
      row.cells[1].value = c.location ?? "";
      row.cells[2].value = c.cargos ?? "";
      row.cells[3].value = c.idMarkings ?? "";
      row.cells[4].value = c.weight ?? "";
      row.cells[5].value = c.dimensions ?? "";
      row.cells[6].value = c.remarks ?? "";
    }
    cargoTable.style = sf.PdfGridStyle(
      font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 9),
      cellPadding: sf.PdfPaddings(left: 2, top: 2, right: 2, bottom: 2),
    );

    final cargoTableResult = cargoTable.draw(
      page: cargoPage,
      bounds: Rect.fromLTWH(margin, y + 90, cargoWidth - 2 * margin, 0),
    );

    final pageSize = cargoPage.getClientSize();
    double yAfterTable = cargoTableResult!.bounds.bottom + 30;

    // ➤ Responsibility table block
    final double stampAndTextHeight = 100;
    const double responsibilityTableHeight = 110;
    final double requiredHeight =
        stampAndTextHeight + responsibilityTableHeight + 30;

    final bool needsNewPage = yAfterTable + requiredHeight > pageSize.height;

    final targetPage = needsNewPage ? document.pages.add() : cargoPage;
    final targetGraphics = targetPage.graphics;
    final targetPageSize = targetPage.getClientSize();
    final double baseY = targetPageSize.height - requiredHeight - 10;

    // ➤ Stamp Image
    const double stampLeftIndent = 60;
    if (stampBytes != null) {
      final stampImage = sf.PdfBitmap(stampBytes);
      targetGraphics.drawImage(
        stampImage,
        Rect.fromLTWH(margin + stampLeftIndent, baseY, 50, 50),
      );
    }

    // ➤ For and on behalf text
    const double indent = 40;
    double textY = baseY + 55;
    targetGraphics.drawString(
      "For and on behalf of",
      normalFont,
      bounds: Rect.fromLTWH(
        margin + indent,
        textY,
        targetPageSize.width - indent * 2,
        20,
      ),
    );

    textY += 18;

    targetGraphics.drawString(
      CertificateType,
      boldFont,
      bounds: Rect.fromLTWH(
        margin + indent,
        textY,
        targetPageSize.width - indent * 2,
        20,
      ),
    );

    // ➤ Responsibility Table
    final responsibilityTable = buildResponsibilityTable(
      surveyedBy: surveyedBy,
      issuedDate: issuedDate,
      signatureBytes: signatureBytes,
      boldFont: boldFont,
    );

    // ✅ Create Times Roman fonts
    final timesNormal = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 10);
    final timesBold = sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      10,
      style: sf.PdfFontStyle.bold,
    );

    // --- Apply Times Roman to headers ---
    if (responsibilityTable.headers.count > 0) {
      for (int h = 0; h < responsibilityTable.headers.count; h++) {
        final headerRow = responsibilityTable.headers[h];
        for (int j = 0; j < headerRow.cells.count; j++) {
          headerRow.cells[j].style.font = timesBold;
        }
      }
    }

    // --- Apply Times Roman to all body rows ---
    for (int i = 0; i < responsibilityTable.rows.count; i++) {
      final row = responsibilityTable.rows[i];
      for (int j = 0; j < row.cells.count; j++) {
        row.cells[j].style.font = timesNormal;
      }
    }

    // ➤ Draw the table (same layout)
    final double tableY = baseY + stampAndTextHeight;

    responsibilityTable.draw(
      page: targetPage,
      bounds: Rect.fromLTWH(
        margin + 45, // left offset
        tableY, // vertical position
        targetPageSize.width -
            (margin + 45) * 2, // total width reduced symmetrically
        0,
      ),
    );
  }

  // ➤ Add "Work Done Report" Page
  final workDonePage = document.pages.add();
  final workDoneGraphics = workDonePage.graphics;

  // ✅ Remember its index (to skip later)
  final int workDonePageIndex = document.pages.indexOf(workDonePage);
  final workPageWidth = workDonePage.getClientSize().width;
  final workPageHeight = workDonePage.getClientSize().height;
  const double workMargin = 15;
  double yOffset = workMargin;

  // 🔲 Draw Border
  workDoneGraphics.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      workMargin - 10,
      workMargin - 10,
      workPageWidth - (workMargin - 10) * 2,
      workPageHeight - (workMargin - 10) * 2,
    ),
  );

  Future<Uint8List> _readImageAsBytes(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }

  // 🖼️ Draw Aries Logo
  final logoBytes = await _readImageAsBytes('assets/images/Aries.png');
  final logo = sf.PdfBitmap(logoBytes);
  workDoneGraphics.drawImage(logo, Rect.fromLTWH(workMargin, yOffset, 140, 70));

  // 📝 Title: Work Done Report
  workDoneGraphics.drawString(
    "Work Done Report",
    sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      20,
      style: sf.PdfFontStyle.bold,
    ),
    bounds: Rect.fromLTWH(
      workPageWidth - 200, // wider area for text to fit in one line
      yOffset + 25, // slight downward shift
      180, // enough width for full line
      30, // appropriate height for one line
    ),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
  );

  yOffset += 140;
  final justifyFormat = sf.PdfStringFormat(
    alignment: sf.PdfTextAlignment.justify,
  );
  // 📄 Main Paragraph
  final reportText =
      "This is certified that $CertificateType carried out TOWAGE APPROVAL SURVEY "
      "on project $projectTitle at $fromPort, "
      "as per the requirements of $clientName.";

  // 🧱 Font
  final reportFont = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 14);

  // 🧭 Format (Left aligned — natural spacing, no large gaps)
  final leftAlignFormat = sf.PdfStringFormat(
    alignment: sf.PdfTextAlignment.left, // 👈 Left alignment
    lineAlignment: sf.PdfVerticalAlignment.top,
    wordWrap: sf.PdfWordWrapType.word,
  );

  // 👇 Add left-right padding and slight right shift
  const double sidePadding1 = 40; // Adjust as needed
  const double shiftRight = 0; // Optional small right shift

  workDoneGraphics.drawString(
    reportText,
    reportFont,
    bounds: Rect.fromLTWH(
      workMargin + sidePadding1 + shiftRight, // Left offset
      yOffset,
      workPageWidth - 2 * (workMargin + sidePadding1), // Paragraph width
      80, // Height (increase if text may wrap)
    ),
    format: justifyFormat,
  );

  yOffset += 120;

  // 🔹 Job Details Section
  final boldFont1 = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    14,
    style: sf.PdfFontStyle.bold,
  );
  final normalFont1 = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 14);
  // How much you want to push right
  const double shiftRight1 = 20; // try 10–25 for fine control

  // Title (Job Details)
  workDoneGraphics.drawString(
    "Job Details:",
    boldFont1,
    bounds: Rect.fromLTWH(
      workMargin + sidePadding + shiftRight1, // move right slightly
      yOffset,
      workPageWidth -
          2 *
              (workMargin +
                  sidePadding +
                  shiftRight1), // wider box prevents stretching
      20,
    ),
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.left, // ✅ ensures no letter spacing issues
      lineAlignment: sf.PdfVerticalAlignment.top,
    ),
  );

  yOffset += 25;

  // Job No
  workDoneGraphics.drawString(
    "Job No: $certificateNumber",
    normalFont1,
    bounds: Rect.fromLTWH(
      workMargin + sidePadding + shiftRight1, // 👈 moved right
      yOffset,
      400,
      20,
    ),
  );
  yOffset += 30;

  // Duration (shifted slightly left)
  workDoneGraphics.drawString(
    "Duration of Job:    From _______________To_____________",
    normalFont1,
    bounds: Rect.fromLTWH(
      workMargin + sidePadding1 - 4, // 👈 moved 10 pts left
      yOffset,
      500,
      20,
    ),
  );

  yOffset += 30;

  // Description (shifted slightly left)
  const double shiftLeft = 4; // fine-tuning, small left shift

  workDoneGraphics.drawString(
    "Job Description: Towage approval for towage of $towName by $tugName from $fromPort to $toPort",
    normalFont1,
    bounds: Rect.fromLTWH(
      workMargin + sidePadding1 - shiftLeft, // slight left shift
      yOffset,
      workPageWidth - 2 * (workMargin + sidePadding1), // same width
      80, // ✅ increase height (was 40)
    ),
    format: justifyFormat,
  );
  yOffset += 140;
  // After job description yOffset

  // ➤ Aries Representative (moved slightly right)
  const double xShift = 35; // was 15 → increase to move right
  const double blockWidth = 200;

  workDoneGraphics.drawString(
    "Aries Representative",
    boldFont1,
    bounds: Rect.fromLTWH(workMargin + xShift, yOffset, blockWidth, 20),
  );
  yOffset += 20;

  workDoneGraphics.drawString(
    "Name: $surveyedBy",
    normalFont1,
    bounds: Rect.fromLTWH(workMargin + xShift, yOffset, blockWidth, 20),
  );
  yOffset += 20;

  workDoneGraphics.drawString(
    "Signature:",
    normalFont1,
    bounds: Rect.fromLTWH(workMargin + xShift, yOffset, 100, 20),
  );
  yOffset += 20;

  // ➤ Aries Signature Image
  if (signatureBytes != null && signatureBytes.isNotEmpty) {
    final signatureImage = sf.PdfBitmap(signatureBytes);
    workDoneGraphics.drawImage(
      signatureImage,
      Rect.fromLTWH(workMargin + xShift, yOffset, 80, 30),
    );
    yOffset += 35;
  } else {
    yOffset += 30;
  }

  // ➤ Aries Date
  workDoneGraphics.drawString(
    "Date: $issuedDate",
    normalFont1,
    bounds: Rect.fromLTWH(workMargin + xShift, yOffset, 100, 20),
  );

  // ➤ 🧾 STAMP Image logic (middle right beside Aries block)
  if (stampBytes != null && stampBytes.isNotEmpty) {
    final stampImage = sf.PdfBitmap(stampBytes);
    // aligned vertically with Aries section, and shifted right
    final double stampX = workPageWidth / 2 - 100;
    final double stampY = yOffset - 140;
    workDoneGraphics.drawImage(
      stampImage,
      Rect.fromLTWH(stampX, stampY, 100, 60),
    );
  }

  // ➤ Client Representative (Right Side)
  const double shiftLeft1 = 50; // 👈 move left by 10–20 points as needed

  double rightColX =
      (workPageWidth / 2) + 40 + xShift - shiftLeft1; // 👈 reduced X value
  double rightY = yOffset - 90;

  workDoneGraphics.drawString(
    "Client Representative",
    boldFont1,
    bounds: Rect.fromLTWH(rightColX, rightY, 200, 20),
  );
  rightY += 20;

  workDoneGraphics.drawString(
    "Name:",
    normalFont1,
    bounds: Rect.fromLTWH(rightColX, rightY, 200, 20),
  );
  rightY += 20;

  // Company name (auto-wraps vertically)
  final companyText = sf.PdfTextElement(
    text: "Company: $clientName",
    font: normalFont1,
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.left,
      lineAlignment: sf.PdfVerticalAlignment.top,
      wordWrap: sf.PdfWordWrapType.word, // 👈 enables wrapping
    ),
  );

  // Draw on the actual page, not graphics
  final companyResult = companyText.draw(
    page: workDonePage, // ✅ correct page reference
    bounds: Rect.fromLTWH(
      rightColX,
      rightY,
      200, // width limit for wrapping
      double.infinity, // allows it to grow vertically
    ),
  )!;

  // Update Y based on text height
  rightY = companyResult.bounds.bottom + 5;

  // update Y position based on text height
  rightY = companyResult.bounds.bottom + 5; // add spacing below
  rightY += 20;

  // ➤ Client Signature
  if (clientBytes != null) {
    final clientSignature = sf.PdfBitmap(clientBytes);
    workDoneGraphics.drawImage(
      clientSignature,
      Rect.fromLTWH(rightColX, rightY, 60, 20),
    );
    rightY += 30;
  } else {
    workDoneGraphics.drawString(
      "Signature:",
      normalFont1,
      bounds: Rect.fromLTWH(rightColX, rightY, 200, 20),
    );
    rightY += 20;
  }

  // ➤ Client Date
  rightY += 20;
  workDoneGraphics.drawString(
    "Date:",
    normalFont1,
    bounds: Rect.fromLTWH(rightColX, rightY, 200, 20),
  );

  // 📝 Footer Note Font
  final footerNoteFont = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    9,
    style: sf.PdfFontStyle.italic,
  );

  // ➤ Footer Note (Centered)
  workDoneGraphics.drawString(
    "(Note: White copy – Aries Administration; Rose copy – Aries Accounts; "
    "Pink copy – Client; Yellow copy – Book Copy if Carbon book used, "
    "not applicable for computer printed copy)",
    footerNoteFont,
    bounds: Rect.fromLTWH(
      workMargin + 10,
      workPageHeight - 50,
      workPageWidth - 2 * (workMargin + 10),
      20,
    ),
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.center,
      lineAlignment: sf.PdfVerticalAlignment.middle,
    ),
  );

  // ➤ Ref Note (Left Aligned)
  workDoneGraphics.drawString(
    "Ref.: QHSE/P 11/ CL 02/ Rev 07 / 01 Aug 2020",
    footerNoteFont,
    bounds: Rect.fromLTWH(
      workMargin + 10,
      workPageHeight - 30,
      workPageWidth - 2 * (workMargin + 10),
      15,
    ),
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.left,
      lineAlignment: sf.PdfVerticalAlignment.top,
    ),
  );

  workDoneGraphics.drawString(
    "Page 1 of 1",
    sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 7),
    bounds: Rect.fromLTWH(workPageWidth - 80, workPageHeight - 15, 70, 10),
  );

  ///////////////////////////////////////////////////////////////////////////////////////

  // ➤ Add Work Done Page 1 (Time Sheet Page)
  final workDonePage1 = document.pages.add();
  final workDoneGraphics1 = workDonePage1.graphics;
  // ✅ Remember its index (to skip later)
  final int timesheetPageIndex = document.pages.indexOf(workDonePage1);
  final workPageWidth1 = workDonePage1.getClientSize().width;
  final workPageHeight1 = workDonePage1.getClientSize().height;

  const double workMargin1 = 15;
  double yOffset1 = workMargin1;

  // 🔲 Draw Border
  workDoneGraphics1.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      workMargin1 - 10,
      workMargin1 - 10,
      workPageWidth1 - (workMargin1 - 10) * 2,
      workPageHeight1 - (workMargin1 - 10) * 2,
    ),
  );

  // 🖼️ Aries Logo (top-left)
  final logoBytes1 = await _readImageAsBytes('assets/images/Aries.png');
  final logo1 = sf.PdfBitmap(logoBytes1);
  workDoneGraphics1.drawImage(
    logo1,
    Rect.fromLTWH(workMargin1, yOffset1, 140, 60),
  );

  // 📝 Title: Time Sheet (top-right)
  workDoneGraphics1.drawString(
    "Time Sheet",
    sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      20,
      style: sf.PdfFontStyle.bold,
    ),
    bounds: Rect.fromLTWH(workPageWidth1 - 200, yOffset1 + 15, 180, 30),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
  );

  // ⬇ Move below logo/title
  yOffset1 += 80;

  // ➤ Client Info Table
  final clientInfoTable = sf.PdfGrid();
  clientInfoTable.columns.add(count: 2);

  final clientDetails = [
    ["CLIENT", "$clientName"],
    ["VESSEL/PROJECT NAME", '$projectTitle'],
    ["LOCATION", "$fromPort"],
    ["NAME OF PERSON", "$surveyedBy"],
    ["TIMESHEET NO", "01"],
    ["JOB NO", "$jobNumber"],
    ["TYPE OF JOB", "TOWAGE APPROVAL"],
  ];

  for (final row in clientDetails) {
    final gridRow = clientInfoTable.rows.add();
    gridRow.cells[0].value = row[0];
    gridRow.cells[1].value = row[1];

    gridRow.cells[0].style = sf.PdfGridCellStyle(
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        10,
        style: sf.PdfFontStyle.bold,
      ),
    );
  }

  clientInfoTable.style = sf.PdfGridStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 10),
    cellPadding: sf.PdfPaddings(left: 4, top: 4, right: 4, bottom: 4),
  );

  // ➤ Draw Client Info Table & calculate height

  final clientLayoutResult = clientInfoTable.draw(
    page: workDonePage1,
    bounds: Rect.fromLTWH(
      workMargin1,
      yOffset1,
      workPageWidth1 - 1 * workMargin1,
      0,
    ),
  );

  // ✅ Use layout result to move below client table
  yOffset1 = clientLayoutResult!.bounds.bottom + 15;
  // ➤ Time Sheet Table
  final timeSheetGrid = sf.PdfGrid();
  timeSheetGrid.columns.add(count: 5);

  // Header Row 1
  final headerRow1 = timeSheetGrid.headers.add(2)[0];
  headerRow1.cells[0].value = 'DATE';
  headerRow1.cells[1].value = 'TIME';
  headerRow1.cells[3].value = 'TOTAL HOURS';
  headerRow1.cells[4].value = 'REMARKS';
  headerRow1.cells[1].columnSpan = 2;

  // Header Row 2
  final headerRow2 = timeSheetGrid.headers[1];
  headerRow2.cells[1].value = 'FROM';
  headerRow2.cells[2].value = 'TO';

  // Empty Rows (with expanded height)
  for (int i = 0; i < 6; i++) {
    final row = timeSheetGrid.rows.add();
    row.height = 20;
  }

  // Consumables Row (spanning full width)
  final consumablesRow = timeSheetGrid.rows.add();
  consumablesRow.cells[0].value = 'Consumables';
  consumablesRow.cells[0].columnSpan = 5;
  consumablesRow.height = 20;

  // ➕ Additional Rows after Consumables (with height)
  for (int i = 0; i < 4; i++) {
    final row = timeSheetGrid.rows.add();
    row.height = 20;
  }

  // Style & Layout
  timeSheetGrid.style = sf.PdfGridStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 9),
    cellPadding: sf.PdfPaddings(left: 3, top: 3, right: 3, bottom: 3),
  );

  // Width Adjustments
  timeSheetGrid.columns[0].width = 60; // Date
  timeSheetGrid.columns[1].width = 40; // Time From
  timeSheetGrid.columns[2].width = 40; // Time To
  timeSheetGrid.columns[3].width = 60; // Total Hours
  timeSheetGrid.columns[4].width =
      workPageWidth1 - workMargin1 * 2 - (60 + 40 + 40 + 60); // Remarks

  // ➤ Draw the Time Sheet Table
  timeSheetGrid.draw(
    page: workDonePage1,
    bounds: Rect.fromLTWH(
      workMargin1,
      yOffset1,
      workPageWidth1 - 2 * workMargin1,
      0,
    ),
  );

  // ✅ Page is now clearly stacked and aligned!
  final boldFont2 = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    10,
    style: sf.PdfFontStyle.bold,
  );
  final normalFont2 = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 10);

  const double xShift1 = 15;
  final double rightColX1 = (workPageWidth1 / 2) + 40 + xShift;
  final double bottomMargin = 80;

  // Calculate bottom start point for footer columns
  double repYOffset = workPageHeight1 - bottomMargin - 100;

  // ✅ Aries Representative (Left)

  // Assuming you already have:
  // Uint8List approverSignatureImageData;
  // and double repYOffset is already defined

  // Aries Representative Title
  workDoneGraphics1.drawString(
    "Aries Representative",
    boldFont1,
    bounds: Rect.fromLTWH(workMargin1 + xShift, repYOffset, 200, 20),
  );
  repYOffset += 20;

  // Name
  workDoneGraphics1.drawString(
    "Name: $surveyedBy",
    normalFont1,
    bounds: Rect.fromLTWH(workMargin1 + xShift, repYOffset, 200, 20),
  );
  repYOffset += 20;

  // Signature label
  workDoneGraphics1.drawString(
    "Signature:",
    normalFont1,
    bounds: Rect.fromLTWH(workMargin1 + xShift, repYOffset, 100, 20),
  );
  repYOffset += 20;

  // Signature image (if available)
  if (signatureBytes != null && signatureBytes.isNotEmpty) {
    final signatureImage = sf.PdfBitmap(signatureBytes);
    workDoneGraphics1.drawImage(
      signatureImage,
      Rect.fromLTWH(workMargin1 + xShift, repYOffset, 80, 30),
    );
    repYOffset += 35; // Add spacing below image
  } else {
    repYOffset += 30; // Still add spacing even if no image
  }

  workDoneGraphics.drawString(
    "Date: $issuedDate",
    normalFont1,
    bounds: Rect.fromLTWH(workMargin + xShift, yOffset, 200, 20),
  );
  // ➤ 🧾 STAMP Image logic (middle right beside Aries block)
  if (stampBytes != null && stampBytes.isNotEmpty) {
    final stampImage = sf.PdfBitmap(stampBytes);
    // aligned vertically with Aries section, and shifted right
    final double stampX = workPageWidth / 2 - 100;
    final double stampY = yOffset - 60;
    workDoneGraphics1.drawImage(
      stampImage,
      Rect.fromLTWH(stampX, stampY, 100, 60),
    );
  }

  // ✅ Client Representative (Right)
  double rightY1 = workPageHeight1 - bottomMargin - 100;
  workDoneGraphics1.drawString(
    "Client Representative",
    boldFont1,
    bounds: Rect.fromLTWH(rightColX, rightY1, 200, 20),
  );
  rightY1 += 20;
  workDoneGraphics1.drawString(
    "Name:",
    normalFont1,
    bounds: Rect.fromLTWH(rightColX, rightY1, 200, 20),
  );
  rightY1 += 20;
  workDoneGraphics1.drawString(
    "Company: $clientName",
    normalFont1,
    bounds: Rect.fromLTWH(rightColX, rightY1, 200, 20),
  );
  rightY1 += 20;
  if (clientBytes != null) {
    final clientSignature = sf.PdfBitmap(clientBytes);
    workDoneGraphics1.drawImage(
      clientSignature,
      Rect.fromLTWH(rightColX, rightY1, 60, 20), // adjust size as needed
    );
    rightY1 += 30; // add spacing after image
  } else {
    workDoneGraphics1.drawString(
      "Signature:",
      normalFont1,
      bounds: Rect.fromLTWH(rightColX, rightY1, 200, 20),
    );
    rightY1 += 10;
  }

  // rightY1 += 5;
  workDoneGraphics1.drawString(
    "Date:",
    normalFont1,
    bounds: Rect.fromLTWH(rightColX, rightY1, 200, 20),
  );
  // 📝 Footer Note Font
  final footerNoteFont1 = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    9,
    style: sf.PdfFontStyle.italic,
  );

  // ➤ Footer Note (Centered)
  workDoneGraphics1.drawString(
    "(Note: White copy – Aries Administration; Rose copy – Aries Accounts; "
    "Pink copy – Client; Yellow copy – Book Copy if Carbon book used, "
    "not applicable for computer printed copy)",
    footerNoteFont1,
    bounds: Rect.fromLTWH(
      workMargin1 + 10,
      workPageHeight1 - 50,
      workPageWidth1 - 2 * (workMargin1 + 10),
      20,
    ),
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.center,
      lineAlignment: sf.PdfVerticalAlignment.middle,
    ),
  );

  // ➤ Ref Note (Left Aligned)
  workDoneGraphics1.drawString(
    "Ref.: QHSE/P 11/ CL 02/ Rev 07 / 01 Aug 2020",
    footerNoteFont1,
    bounds: Rect.fromLTWH(
      workMargin1 + 10,
      workPageHeight1 - 30,
      workPageWidth1 - 2 * (workMargin1 + 10),
      10,
    ),
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.left,
      lineAlignment: sf.PdfVerticalAlignment.top,
    ),
  );

  // 📄 Page No
  workDoneGraphics1.drawString(
    "Page 1 of 1",
    sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 7),
    bounds: Rect.fromLTWH(workPageWidth1 - 80, workPageHeight1 - 15, 70, 10),
  );

  ///////////////////////////////////////////////////////////////////////////
  // ✅ New Page for Checklist
  final checklistPage = document.pages.add();
  final checklistGraphics = checklistPage.graphics;

  // ✅ Distinct names for dimensions and margin
  final double checklistPageWidth = checklistPage.getClientSize().width;
  final double checklistPageHeight = checklistPage.getClientSize().height;
  const double checklistMargin = 15;
  double checklistYOffset = checklistMargin;

  // 🔲 Border
  checklistGraphics.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      checklistMargin - 10,
      checklistMargin - 10,
      checklistPageWidth - 2 * (checklistMargin - 10),
      checklistPageHeight - 2 * (checklistMargin - 10),
    ),
  );

  // 🖼️ Logo Top-Left
  final checklistLogo = sf.PdfBitmap(
    await _readImageAsBytes('assets/images/Logo.png'),
  );
  checklistGraphics.drawImage(
    checklistLogo,
    Rect.fromLTWH(checklistMargin, checklistYOffset, 140, 80),
  );

  // 👇 RIGHT SIDE TITLE BLOCK - aligned with logo
  final double rightTitleX = checklistMargin + 150; // Shift right of logo
  final double titleWidth = checklistPageWidth - rightTitleX - checklistMargin;

  checklistGraphics.drawString(
    "$CertificateType",
    sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      13,
      style: sf.PdfFontStyle.bold,
    ),
    bounds: Rect.fromLTWH(
      rightTitleX - 10, // slight left
      checklistYOffset + 60, // moved 5 units more downward (was +10)
      titleWidth,
      20,
    ),

    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
  );

  // 📝 Main Titles just below logo
  checklistYOffset += 75; // push everything below logo

  // 🔲 Grid with Project, Route, CoA, Job No.
  final infoGrid = sf.PdfGrid();
  infoGrid.columns.add(count: 4);
  infoGrid.headers.add(2); // 2 header rows

  // Header Row 1
  final header1 = infoGrid.headers[0];
  header1.cells[0].columnSpan = 3;
  header1.cells[0].value = "PROJECT NAME :$projectTitle";
  header1.cells[3].value = "TOWAGE SURVEY";

  // Header Row 2
  final header2 = infoGrid.headers[1];
  header2.cells[0].columnSpan = 2;
  header2.cells[0].value = "Route:$fromPort to $toPort";
  header2.cells[2].value = "CoA No: $jobNumber/$certificateNumber";
  header2.cells[3].value = "Job No: $jobNumber";

  // Apply styles to all header rows safely
  for (int r = 0; r < infoGrid.rows.count; r++) {
    final row = infoGrid.rows[r];
    for (int c = 0; c < row.cells.count; c++) {
      final cell = row.cells[c];
      cell.style = sf.PdfGridCellStyle(
        font: sf.PdfStandardFont(
          sf.PdfFontFamily.timesRoman,
          10,
          style: sf.PdfFontStyle.regular,
        ),
      );
    }
  }

  // 🟩 Vessel Info Grid (below project grid)
  final vesselGrid = sf.PdfGrid();
  vesselGrid.columns.add(count: 5);
  vesselGrid.headers.add(1);

  final vesselHeader = vesselGrid.headers[0];
  vesselHeader.cells[0].value = "Vessel";
  vesselHeader.cells[1].value = "Name";
  vesselHeader.cells[2].value = "IMO No. if any (or owner /flag)";
  vesselHeader.cells[3].value = "Survey report no. & date";
  vesselHeader.cells[4].value = "";

  for (int i = 0; i < vesselHeader.cells.count; i++) {
    vesselHeader.cells[i].style = sf.PdfGridCellStyle(
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        10,
        style: sf.PdfFontStyle.bold,
      ),
      backgroundBrush: sf.PdfSolidBrush(
        sf.PdfColor(217, 217, 217),
      ), // light grey
      cellPadding: sf.PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );
  }

  // Rows
  vesselGrid.rows.add().cells[0].value = "Transport ship or barge";
  vesselGrid.rows[0].cells[1].value = "$tugName";

  vesselGrid.rows.add().cells[0].value = "Towing vessel 1";
  vesselGrid.rows[1].cells[1].value = "$towName";

  vesselGrid.rows.add().cells[0].value = "Towing vessel 2";

  // ⬛ STYLE HELPER FOR GRIDS
  void styleGrid(sf.PdfGrid grid) {
    grid.style = sf.PdfGridStyle(
      font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 10),
      cellPadding: sf.PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );
  }

  // 🟩 Style and Draw Project Info Grid
  styleGrid(infoGrid);
  final infoBounds = infoGrid.draw(
    page: checklistPage,
    bounds: Rect.fromLTWH(
      checklistMargin,
      checklistYOffset,
      checklistPageWidth - 2 * checklistMargin,
      0, // let it auto-calculate height
    ),
  )!;
  checklistYOffset = infoBounds.bounds.bottom + 5;

  // 🟩 Style and Draw Vessel Info Grid
  styleGrid(vesselGrid);
  final vesselBounds = vesselGrid.draw(
    page: checklistPage,
    bounds: Rect.fromLTWH(
      checklistMargin,
      checklistYOffset,
      checklistPageWidth - 2 * checklistMargin,
      0,
    ),
  )!;
  checklistYOffset = vesselBounds.bounds.bottom + 10;
  // 📋 Checklist Grid Creation
  final checklistGrid = sf.PdfGrid();
  checklistGrid.columns.add(count: 4);
  checklistGrid.columns[0].width = 40; // 1st column: narrow (serial number)
  checklistGrid.columns[1].width = 180; // 2nd column: main description
  checklistGrid.columns[2].width = 50; // 3rd column: STATUS (smaller)
  checklistGrid.columns[3].width = 190; // 4th column: Comments (wider)

  // 🔳 Top Header Row
  final topHeader = checklistGrid.headers.add(1)[0];
  topHeader.cells[0].value = "1";
  topHeader.cells[1].value = "FOR ALL TYPES OF TOW/TRANSPORT";
  topHeader.cells[2].value = "STATUS (Tick or NA)";
  topHeader.cells[3].value = "Comments";

  // 🔳 Style Top Header
  for (int i = 0; i < 4; i++) {
    topHeader.cells[i].style = sf.PdfGridCellStyle(
      backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        9,
        style: sf.PdfFontStyle.bold,
      ),
    );
  }

  // 🧩 Helper for Subheaders
  void addSubHeader(String title) {
    final row = checklistGrid.rows.add();
    row.cells[0].columnSpan = 4;
    row.cells[0].value = title;
    row.cells[0].style = sf.PdfGridCellStyle(
      backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        9,
        style: sf.PdfFontStyle.bold,
      ),
    );
  }

  // 🔻 Section 1
  addSubHeader("Condition & (de)ballasting");
  final checklistItems = [
    [
      "1.1",
      "Documentation & outstanding recommendations for (towed) hull & equipment.",
    ],
    ["1.2", "Condition of (towed) hull & equipment."],
    [
      "1.3",
      "Watertight integrity of (towed) hull, deck openings, valves, vents, portholes & closures.",
    ],
    [
      "1.4",
      "Confirm adequate means for pumping out water ingress & counter-flooding",
    ],
    ["1.5", "Green water protection of cargo (/tow connection)."],
    [
      "1.6",
      "Final loading / ballast condition of (towed) vessel checked for stability... All residual ballast water stripped out.",
    ],
  ];

  // Add rows
  for (final item in checklistItems) {
    final row = checklistGrid.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // 🔻 Section 2
  addSubHeader("Seafastening / storage");
  final seaFasteningItems = [
    [
      "1.7",
      "Correct layout of seafastenings,supports and grillage etc.(pre-loadout)",
    ],
    [
      "1.8",
      "Check on seafastening design changes or agreed site modifications",
    ],
    [
      "1.9",
      "Integrity of cargo and seafastening to hull (deck, Material Certs, Weld procedures, Welder qualifications, NDT Certs as appropriate...)",
    ],
  ];

  // Add rows
  for (final item in seaFasteningItems) {
    final row = checklistGrid.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // ✅ Final Grid Style (compact)

  // ✅ Final Grid Style (compact)
  checklistGrid.style = sf.PdfGridStyle(
    font: sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      8.5,
    ), // 👈 slightly smaller
    cellPadding: sf.PdfPaddings(left: 2, right: 2, top: 5, bottom: 5),
  );
  // ✅ Draw the Checklist Grid
  final checklistBounds = checklistGrid.draw(
    page: checklistPage,
    bounds: Rect.fromLTWH(
      checklistMargin + 5,
      checklistYOffset,
      checklistPageWidth - 2 * checklistMargin - 10,
      0,
    ),
    format: sf.PdfLayoutFormat(layoutType: sf.PdfLayoutType.paginate),
  );

  checklistYOffset = checklistBounds!.bounds.bottom + 10;

  // ✅ Add new page
  final checklistPage1 = document.pages.add();
  final checklistGraphics1 = checklistPage1.graphics;

  // ✅ Use separate dimensions/margins for the new page
  final double checklistPageWidth1 = checklistPage1.getClientSize().width;
  final double checklistPageHeight1 = checklistPage1.getClientSize().height;
  const double checklistMargin1 = 15;
  double checklistYOffset1 = checklistMargin1;

  // 🔲 Border for new page
  checklistGraphics1.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      checklistMargin1 - 10,
      checklistMargin1 - 10,
      checklistPageWidth1 - 2 * (checklistMargin1 - 10),
      checklistPageHeight1 - 2 * (checklistMargin1 - 10),
    ),
  );

  // ✅ Logo (smaller)
  final checklistLogo1 = sf.PdfBitmap(
    await _readImageAsBytes('assets/images/Logo.png'),
  );
  checklistGraphics1.drawImage(
    checklistLogo1,
    Rect.fromLTWH(checklistMargin1, checklistYOffset1, 110, 60),
  );

  // ✅ Right-side title
  final double rightTitleX1 = checklistMargin1 + 80; // ⬅️ shifted 10px left
  final double titleWidth1 =
      checklistPageWidth1 - rightTitleX1 - checklistMargin1;
  checklistGraphics1.drawString(
    "$CertificateType",
    sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      12,
      style: sf.PdfFontStyle.bold,
    ),
    bounds: Rect.fromLTWH(
      rightTitleX1,
      checklistYOffset1 + 40,
      titleWidth1,
      20,
    ),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
  );

  // ✅ Title space
  checklistYOffset1 += 60;

  // ✅ Project Info Grid
  final infoGrid1 = sf.PdfGrid();
  infoGrid1.columns.add(count: 4);
  infoGrid1.headers.add(2);

  // Header rows
  final header3 = infoGrid1.headers[0];
  header3.cells[0].columnSpan = 3;
  header3.cells[0].value = 'PROJECT NAME :$projectTitle';
  header3.cells[3].value = 'TOWAGE SURVEY';

  final header4 = infoGrid1.headers[1];
  header4.cells[0].columnSpan = 2;
  header4.cells[0].value = "Route:$fromPort to $toPort";
  header4.cells[2].value = "CoA No: $jobNumber/$certificateNumber";
  header4.cells[3].value = "Job No: $jobNumber";

  // Style project grid
  for (int i = 0; i < infoGrid1.headers.count; i++) {
    final row = infoGrid1.headers[i];
    for (int j = 0; j < row.cells.count; j++) {
      row.cells[j].style = sf.PdfGridCellStyle(
        font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 9),
        cellPadding: sf.PdfPaddings(left: 2, right: 2, top: 1.5, bottom: 1.5),
      );
    }
  }

  // Draw info grid
  final infoBounds1 = infoGrid1.draw(
    page: checklistPage1,
    bounds: Rect.fromLTWH(
      checklistMargin1,
      checklistYOffset1,
      checklistPageWidth1 - 2 * checklistMargin1,
      0,
    ),
  )!;

  // Update offset
  checklistYOffset1 = infoBounds1.bounds.bottom + 6;

  // ✅ Checklist Grid
  final checklistGrid1 = sf.PdfGrid();
  checklistGrid1.columns.add(count: 4);
  checklistGrid1.columns[0].width = 40; // 1st column: narrow (serial number)
  checklistGrid1.columns[1].width = 180; // 2nd column: main description
  checklistGrid1.columns[2].width = 50; // 3rd column: STATUS (smaller)
  checklistGrid1.columns[3].width = 190; // 4th column: Comments (wider)

  // 🔳 Header Row
  final topHeader1 = checklistGrid1.headers.add(1)[0];
  topHeader1.cells[0].value = "1";
  topHeader1.cells[1].value = "FOR ALL TYPES OF TOW/TRANSPORT";
  topHeader1.cells[2].value = "STATUS (Tick or NA)";
  topHeader1.cells[3].value = "Comments";
  for (int i = 0; i < 4; i++) {
    topHeader1.cells[i].style = sf.PdfGridCellStyle(
      backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        9,
        style: sf.PdfFontStyle.bold,
      ),
    );
  }

  // 🔧 Subheader helper
  void addSubHeader1(String title) {
    final row = checklistGrid1.rows.add();
    row.cells[0].columnSpan = 4;
    row.cells[0].value = title;
    row.cells[0].style = sf.PdfGridCellStyle(
      backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        9,
        style: sf.PdfFontStyle.bold,
      ),
    );
  }

  // 📦 Add Checklist Itemsvoid addSubheader1
  addSubHeader1("");
  final checklistItems1 = [
    [
      "1.10",
      " Sea fastening / storing of shipped loose items including any wire slings, rigging & shackles tight as appropriate.",
    ],
    [
      "1.11",
      "Internal sea fastening & no loose items that can drop e.g. during lift.  Barge and module swept clean.",
    ],
    ["1.12", "Cranes and derricks secured."],
    ["1.13", "Security of dangerous goods"],
    ["1.14", "Protection of pressurized tanks or receptacles"],
  ];

  for (final item in checklistItems1) {
    final row = checklistGrid1.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // 📦 More items
  addSubHeader1("Miscellaneous");
  final seaFasteningItems1 = [
    [
      "1.15",
      "Legs, cantilever, water tower etc confirmed as at correct height /position.",
    ],
    [
      "1.16",
      "Light & signals (international & local lights & shapes – with adequate spares).",
    ],
    [
      "1.17",
      "Pilotage, assisting tugs etc.required for departure with hand-overs defined.",
    ],
    ["1.18", "Guard /escort vessel (for any phases)"],
    ["1.19", "No head room (air draught) restriction for voyage/tow"],
    [
      "1.20",
      "Marine procedures including weather forecasting and/or routing advisory service to be provided for the voyage & discussed with Master",
    ],
    ["1.21", "Weather conditions and forecast suitable for departure"],
    [
      "1.22",
      "Agreed progress reporting system established between the vessel and the cargo owners.",
    ],
    ["1.23", "Manning - LSA, FFE, accommodation,communications etc."],
  ];

  for (final item in seaFasteningItems1) {
    final row = checklistGrid1.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // 📦 Final Checks
  addSubHeader1("Final checks");
  final checklistItems2 = [
    [
      "1.24",
      "Riding crew, if carried, or HL vessel crew briefed for regular checks and fire watch throughout voyage.",
    ],
    ["1.25", "Access to towed hulls, boarding ladders etc"],

    [
      "1.26",
      "Final check of cargo to ensure all equipment internally and externally is secure.",
    ],

    [
      "1.27",
      "Dimensional check on grillage and seafastening to ensure design changes and agreed site modification have been implemented.",
    ],

    [
      "1.28",
      "Verify post loadout re-instatement completed OK & re classed if necessary.",
    ],
  ];

  for (final item in checklistItems2) {
    final row = checklistGrid1.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // ✅ Style checklist grid
  checklistGrid1.style = sf.PdfGridStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
    cellPadding: sf.PdfPaddings(left: 2, right: 2, top: 1, bottom: 1),
  );

  // ✅ Draw checklist table
  checklistGrid1.draw(
    page: checklistPage1,
    bounds: Rect.fromLTWH(
      checklistMargin1,
      checklistYOffset1,
      checklistPageWidth1 - 2 * checklistMargin1,
      checklistPageHeight1 - checklistYOffset1 - checklistMargin1,
    ),
    format: sf.PdfLayoutFormat(layoutType: sf.PdfLayoutType.onePage),
  );

  checklistYOffset1 = infoBounds1.bounds.bottom + 10;

  // ---------------- Page 2 ----------------
  final sf.PdfPage checklistPage2 = document.pages.add();
  final sf.PdfGraphics checklistGraphics2 = checklistPage2.graphics;

  final double checklistPageWidth2 = checklistPage2.getClientSize().width;
  final double checklistPageHeight2 = checklistPage2.getClientSize().height;
  const double checklistMargin2 = 15;
  double checklistYOffset2 = checklistMargin2;

  // Border
  checklistGraphics2.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      checklistMargin2 - 10,
      checklistMargin2 - 10,
      checklistPageWidth2 - 2 * (checklistMargin2 - 10),
      checklistPageHeight2 - 2 * (checklistMargin2 - 10),
    ),
  );

  // Logo
  final sf.PdfBitmap checklistLogo2 = sf.PdfBitmap(
    await _readImageAsBytes('assets/images/Logo.png'),
  );
  checklistGraphics2.drawImage(
    checklistLogo2,
    Rect.fromLTWH(checklistMargin2, checklistYOffset2, 110, 60),
  );

  // Right-side title
  final double rightTitleX2 = checklistMargin2 + 130;
  final double titleWidth2 =
      checklistPageWidth2 - rightTitleX2 - checklistMargin2;
  checklistGraphics2.drawString(
    "$CertificateType",
    sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      12,
      style: sf.PdfFontStyle.bold,
    ),
    bounds: Rect.fromLTWH(
      rightTitleX2,
      checklistYOffset2 + 40,
      titleWidth2,
      20,
    ),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
  );

  checklistYOffset2 += 60;

  // ---------- Header info table ----------
  final sf.PdfGrid infoGrid2 = sf.PdfGrid();
  infoGrid2.columns.add(count: 4);
  infoGrid2.headers.add(2);

  final header5 = infoGrid2.headers[0];
  header5.cells[0].columnSpan = 3;
  header5.cells[0].value = 'PROJECT NAME: $projectTitle';
  header5.cells[3].value = 'TOWAGE SURVEY';

  final header6 = infoGrid2.headers[1];
  header6.cells[0].columnSpan = 2;
  header6.cells[0].value = "Route: $fromPort to $toPort";
  header6.cells[2].value = "CoA No: $jobNumber/$certificateNumber";
  header6.cells[3].value = "Job No: $jobNumber";

  // Make header bold Times font
  for (int i = 0; i < infoGrid2.headers.count; i++) {
    final h = infoGrid2.headers[i];
    for (int j = 0; j < h.cells.count; j++) {
      h.cells[j].style = sf.PdfGridCellStyle(
        font: sf.PdfStandardFont(
          sf.PdfFontFamily.timesRoman,
          9,
          style: sf.PdfFontStyle.bold,
        ),
      );
    }
  }

  final infoBounds2 = infoGrid2.draw(
    page: checklistPage2,
    bounds: Rect.fromLTWH(
      checklistMargin2,
      checklistYOffset2,
      checklistPageWidth2 - 2 * checklistMargin2,
      0,
    ),
  )!;

  checklistYOffset2 = infoBounds2.bounds.bottom + 10;

  // ---------- Checklist grid ----------
  final sf.PdfGrid checklistGrid2 = sf.PdfGrid();
  checklistGrid2.columns.add(count: 4);

  // Column widths
  checklistGrid2.columns[0].width = 40; // No.
  checklistGrid2.columns[1].width = 202; // Description
  checklistGrid2.columns[2].width = 40; // Status
  checklistGrid2.columns[3].width = 202; // Comments

  // Subheader
  final subHeader = checklistGrid2.rows.add();
  subHeader.cells[0].columnSpan = 4;
  subHeader.cells[0].value = "FOR TOWAGES ONLY";
  subHeader.cells[0].style = sf.PdfGridCellStyle(
    backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
    font: sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      9,
      style: sf.PdfFontStyle.bold,
    ),
  );

  // 2.1 – 2.11
  final checklistItems3 = <List<String>>[
    [
      "2.1",
      "Towing vessel(s) - equipment, supplies, manning & documentation (see Tug report form).",
    ],
    ["2.2", "Towing vessel(s) - outstanding recommendations."],
    ["2.3", "Towing connections - strength construction and position."],
    ["2.4", "Towing gear strength, composition & condition."],
    ["2.5", "Towing gear fairleads (including chafe)."],
    ["2.6", "Towing gear retrieval systems."],
    ["2.7", "Emergency tow gear (as above)."],
    [
      "2.8",
      "Emergency anchoring systems. Strength, holding & deployment system.",
    ],
    [
      "2.9",
      "Adequate fuel (& contingencies) on board. Confirm refuelling arrangements if required.",
    ],
    [
      "2.10",
      "Power /adequate fuel for navigation lights, lights and shapes in position on tow & tested.",
    ],
    [
      "2.11",
      "All watertight openings closed on departure & ballast system secured (unmanned tows only).",
    ],
  ];

  for (final item in checklistItems3) {
    final r = checklistGrid2.rows.add();
    r.cells[0].value = item[0];
    r.cells[1].value = item[1];
    r.cells[2].value = "";
    r.cells[3].value = "";
  }

  // ---------- 2.12 special row with nested draught table ----------
  final sf.PdfGrid draughtGrid = sf.PdfGrid();
  draughtGrid.columns.add(count: 3);
  draughtGrid.columns[0].width = 62; // Label
  draughtGrid.columns[1].width = 62; // Port
  draughtGrid.columns[2].width = 70; // Starboard

  draughtGrid.headers.add(1);
  final dHdr = draughtGrid.headers[0];
  dHdr.cells[0].value = '';
  dHdr.cells[1].value = 'Port';
  dHdr.cells[2].value = 'Starboard';
  for (int i = 0; i < dHdr.cells.count; i++) {
    dHdr.cells[i].style = sf.PdfGridCellStyle(
      backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        8,
        style: sf.PdfFontStyle.bold,
      ),
    );
  }

  final draughtRows = <MapEntry<String, bool>>[
    const MapEntry('Forward', false),
    const MapEntry('Aft', false),
    const MapEntry('Mean', true), // shade first cell
    const MapEntry('Units:', false),
    const MapEntry('Readability:', false),
  ];

  for (final e in draughtRows) {
    final r = draughtGrid.rows.add();
    r.cells[0].value = e.key;

    if (e.value) {
      r.cells[0].style = sf.PdfGridCellStyle(
        backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(230, 230, 230)),
        font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
      );
    } else {
      r.cells[0].style = sf.PdfGridCellStyle(
        font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
      );
    }

    if (e.key == 'Units:' || e.key == 'Readability:') {
      r.cells[1].columnSpan = 2;
      r.cells[1].value = '';
    } else {
      r.cells[1].value = '';
      r.cells[2].value = '';
    }
  }

  draughtGrid.style = sf.PdfGridStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
    cellPadding: sf.PdfPaddings(left: 2, right: 2, top: 1, bottom: 1),
  );

  final r212 = checklistGrid2.rows.add();
  r212.cells[0].value = "2.12";
  r212.cells[1].value =
      "Barge departure draughts. Please specify if in feet or meters and comment on readability of draught marks";
  r212.cells[1].style = sf.PdfGridCellStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
    format: sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.left,
      lineAlignment: sf.PdfVerticalAlignment.top,
      wordWrap: sf.PdfWordWrapType.word,
    ),
    cellPadding: sf.PdfPaddings(left: 3, right: 3, top: 1, bottom: 1),
  );

  // merge Status + Comments, and place nested grid
  r212.cells[2].columnSpan = 2;
  r212.cells[2].value = draughtGrid;
  r212.cells[2].style = sf.PdfGridCellStyle(
    cellPadding: sf.PdfPaddings(left: 2, right: 2, top: 2, bottom: 2),
  );

  // Optional: extra height to match look
  r212.height = 95;

  // ---------- 2.13–2.14 ----------
  final extraRows = <List<String>>[
    ["2.13", "Tug master given barge departure ballast plan & draughts."],
    [
      "2.14",
      "Tug master and chief engineer shown barge towing connections and pump room",
    ],
  ];

  for (final item in extraRows) {
    final r = checklistGrid2.rows.add();
    r.cells[0].value = item[0];
    r.cells[1].value = item[1];
    r.cells[2].value = "";
    r.cells[3].value = "";
  }

  // ---------- Additional for towed ships ----------
  final subHeader2 = checklistGrid2.rows.add();
  subHeader2.cells[0].columnSpan = 4;
  subHeader2.cells[0].value = "ADDITIONAL FOR TOWED SHIPS ONLY";
  subHeader2.cells[0].style = sf.PdfGridCellStyle(
    backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
    font: sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      9,
      style: sf.PdfFontStyle.bold,
    ),
  );

  final checklistItems4 = <List<String>>[
    ["3.1", "Ensure rudder immobilized in amidships position."],
    ["3.2", "Confirm propeller shaft disconnected."],
    ["3.3", "Check if any (additional) cargo loaded or to be loaded."],
  ];

  for (final item in checklistItems4) {
    final r = checklistGrid2.rows.add();
    r.cells[0].value = item[0];
    r.cells[1].value = item[1];
    r.cells[2].value = "";
    r.cells[3].value = "";
  }

  // Global grid style
  checklistGrid2.style = sf.PdfGridStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
    cellPadding: sf.PdfPaddings(left: 2, right: 3, top: 2, bottom: 3),
  );

  // Render (one page as requested)
  final checklistGridResult = checklistGrid2.draw(
    page: checklistPage2,
    bounds: Rect.fromLTWH(
      checklistMargin2,
      checklistYOffset2,
      checklistPageWidth2 - 2 * checklistMargin2,
      checklistPageHeight2 - checklistYOffset2 - checklistMargin2,
    ),
    format: sf.PdfLayoutFormat(layoutType: sf.PdfLayoutType.onePage),
  )!;

  // ✅ Add new page
  final checklistPage3 = document.pages.add();
  final checklistGraphics3 = checklistPage3.graphics;

  // ✅ Page size & margins
  final double checklistPageWidth3 = checklistPage3.getClientSize().width;
  final double checklistPageHeight3 = checklistPage3.getClientSize().height;
  const double checklistMarginLeft3 = 10; // tighter left
  const double checklistMarginRight3 = 20; // 🔹 slightly larger right margin
  double checklistYOffset3 = checklistMarginLeft3;

  // 🔲 Border (aligned with new margins)
  checklistGraphics3.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      checklistMarginLeft3 - 8,
      checklistMarginLeft3 - 8,
      checklistPageWidth3 - checklistMarginLeft3 - checklistMarginRight3 + 16,
      checklistPageHeight3 - 2 * (checklistMarginLeft3 - 8),
    ),
  );

  // ✅ Logo
  final checklistLogo3 = sf.PdfBitmap(
    await _readImageAsBytes('assets/images/Logo.png'),
  );
  checklistGraphics3.drawImage(
    checklistLogo3,
    Rect.fromLTWH(checklistMarginLeft3, checklistYOffset3, 100, 55),
  );

  // ✅ Title on right side
  final double rightTitleX3 = checklistMarginLeft3 + 120;
  final double titleWidth3 =
      checklistPageWidth3 -
      rightTitleX3 -
      checklistMarginRight3 -
      5; // reduced right space
  checklistGraphics3.drawString(
    "$CertificateType",
    sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      12,
      style: sf.PdfFontStyle.bold,
    ),
    bounds: Rect.fromLTWH(
      rightTitleX3,
      checklistYOffset3 + 40,
      titleWidth3,
      20,
    ),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
  );

  checklistYOffset3 += 60;

  // ✅ Info Header Table
  final infoGrid3 = sf.PdfGrid();
  infoGrid3.columns.add(count: 4);
  infoGrid3.headers.add(2);

  final header7 = infoGrid3.headers[0];
  header7.cells[0].columnSpan = 3;
  header7.cells[0].value = 'PROJECT NAME : $projectTitle';
  header7.cells[3].value = 'TOWAGE SURVEY';

  final header8 = infoGrid3.headers[1];
  header8.cells[0].columnSpan = 2;
  header8.cells[0].value = "Route: $fromPort to $toPort";
  header8.cells[2].value = "CoA No: $jobNumber/$toPort";
  header8.cells[3].value = "Job No: $jobNumber";

  // ✅ Draw info table
  final infoBounds3 = infoGrid3.draw(
    page: checklistPage3,
    bounds: Rect.fromLTWH(
      checklistMarginLeft3 - 4,
      checklistYOffset3,
      checklistPageWidth3 - checklistMarginLeft3 - checklistMarginRight3 + 8,
      0,
    ),
  )!;

  checklistYOffset3 = infoBounds3.bounds.bottom + 10;

  // ✅ Checklist Grid
  final checklistGrid3 = sf.PdfGrid();
  checklistGrid3.columns.add(count: 4);

  checklistGrid3.columns[0].width = 40; // 1st column: narrow (serial number)
  checklistGrid3.columns[1].width = 202; // 2nd column: main description
  checklistGrid3.columns[2].width = 40; // 3rd column: STATUS (smaller)
  checklistGrid3.columns[3].width = 202; // 4th column: Comments (wider)

  // SECTION 4
  final subHeader4 = checklistGrid3.rows.add();
  subHeader4.cells[0].value = "4";
  subHeader4.cells[1].value = "For FLOATED ON cargoes (e.g. MODUs) only";
  subHeader4.cells[2].value = "OK";
  subHeader4.cells[3].value = "Comments";
  subHeader4.style = sf.PdfGridRowStyle(
    backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
    font: sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      9,
      style: sf.PdfFontStyle.bold,
    ),
  );

  // Section 4 rows
  final checklistItems5 = [
    ["4.1", "Cargo/MODU correctly positioned against guide posts."],
    ["4.2", "Cargo/MODU seated on cribbing and adequately supported."],
    [
      "4.3",
      "All seafastenings correctly positioned and all welds verified per approved drawings.",
    ],
  ];
  for (final item in checklistItems5) {
    final row = checklistGrid3.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // SECTION 5
  final subHeader5 = checklistGrid3.rows.add();
  subHeader5.cells[0].value = "5";
  subHeader5.cells[1].value = "FOR CARGOS ON HL VESSELS (e.g. MODUs) ONLY";
  subHeader5.cells[2].value = "OK";
  subHeader5.cells[3].value = "Comments";
  subHeader5.style = sf.PdfGridRowStyle(
    backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
    font: sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      9,
      style: sf.PdfFontStyle.bold,
    ),
  );

  final checklistItems6 = [
    ["5.1", "Safe and adequate access between HL vessel and cargo provided."],
    ["5.2", "Firefighting water connected from HL vessel to cargo system."],
    ["5.3", "Proper earthing connection between cargo and HL vessel."],
  ];
  for (final item in checklistItems6) {
    final row = checklistGrid3.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // SECTION 6
  final subHeader6 = checklistGrid3.rows.add();
  subHeader6.cells[0].value = "6";
  subHeader6.cells[1].value = "FOR CARGO TO BE LIFTED ONLY";
  subHeader6.cells[2].value = "OK";
  subHeader6.cells[3].value = "Comments";
  subHeader6.style = sf.PdfGridRowStyle(
    backgroundBrush: sf.PdfSolidBrush(sf.PdfColor(217, 217, 217)),
    font: sf.PdfStandardFont(
      sf.PdfFontFamily.timesRoman,
      9,
      style: sf.PdfFontStyle.bold,
    ),
  );

  final checklistItems7 = [
    ["6.1", "Correct Layout of Spreaders etc (Pre loadout)"],
    ["6.2", "Correct Installation of Restraint Material (Post loadout)"],
    ["6.3", "Wire rigging and shackles checked against certificates."],
  ];
  for (final item in checklistItems7) {
    final row = checklistGrid3.rows.add();
    row.cells[0].value = item[0];
    row.cells[1].value = item[1];
    row.cells[2].value = "";
    row.cells[3].value = "";
  }

  // ✅ Signature block
  final signatureRow = checklistGrid3.rows.add();
  signatureRow.cells[0].columnSpan = 3;
  signatureRow.cells[0].value =
      "All CoA items signed off by\n(Attending Surveyor):\n\nChecklist authorised by\n(Project Manager or authorizer)";
  signatureRow.cells[3].value = "Date";

  signatureRow.cells[0].style = sf.PdfGridCellStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
  );
  signatureRow.cells[3].style = sf.PdfGridCellStyle(
    font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 8),
  );

  // ✅ Draw grid (balanced margins)
  checklistGrid3.draw(
    page: checklistPage3,
    bounds: Rect.fromLTWH(
      checklistMarginLeft3 - 4,
      checklistYOffset3,
      checklistPageWidth3 - checklistMarginLeft3 - checklistMarginRight3 + 8,
      checklistPageHeight3 - checklistYOffset3 - checklistMarginLeft3,
    ),
    format: sf.PdfLayoutFormat(layoutType: sf.PdfLayoutType.paginate),
  );

  for (int i = 0; i < document.pages.count; i++) {
    // 👇 Skip Work Done or Timesheet pages
    if (i == workDonePageIndex || i == timesheetPageIndex) continue;

    final page = document.pages[i];
    final graphics = page.graphics;
    final pageSize = page.getClientSize();

    graphics.drawString(
      'AM/DS-TC-02_R0',
      sf.PdfStandardFont(
        sf.PdfFontFamily.timesRoman,
        8,
        style: sf.PdfFontStyle.bold,
      ),
      brush: sf.PdfSolidBrush(sf.PdfColor(150, 150, 150)),
      bounds: Rect.fromLTWH(10, pageSize.height - 20, pageSize.width - 30, 20),
      format: sf.PdfStringFormat(
        alignment: sf.PdfTextAlignment.left,
        lineAlignment: sf.PdfVerticalAlignment.middle,
      ),
    );
  }

  ///////////////////////////////////////////////////////////////////////////////
  final bytes = await document.save();
  document.dispose();
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/towage_certificate_flutter.pdf');
  await file.writeAsBytes(bytes);
  await OpenFile.open(file.path);
}

sf.PdfGrid buildResponsibilityTable({
  required String surveyedBy,
  required String issuedDate,
  Uint8List? signatureBytes,
  required sf.PdfFont boldFont,
}) {
  final table = sf.PdfGrid();
  table.columns.add(count: 4); // Only 4 columns

  final header = table.headers.add(1)[0];
  const headers = ['Responsibility', 'Name', 'Signature', 'Date'];
  for (int i = 0; i < headers.length; i++) {
    header.cells[i].value = headers[i];
    header.cells[i].style
      ..font = boldFont
      ..backgroundBrush = sf.PdfBrushes.lightGray;
  }

  final row = table.rows.add();
  row.cells[0].value = 'Issued By';
  row.cells[0].style
    ..font = boldFont
    ..backgroundBrush = sf.PdfBrushes.lightGray;

  row.cells[1].value = surveyedBy;

  if (signatureBytes != null) {
    final sig = sf.PdfBitmap(signatureBytes);
    row.cells[2].value = '';
    row.cells[2].style.backgroundImage = sig;
  } else {
    row.cells[2].value = ''; // Or "Not Signed"
  }

  row.cells[3].value = issuedDate;

  table.style = sf.PdfGridStyle(
    cellPadding: sf.PdfPaddings(left: 4, top: 4, right: 4, bottom: 4),
  );

  return table;
}
