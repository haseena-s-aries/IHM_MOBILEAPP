import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:Auras/Db/database_helper.dart';
import 'package:Auras/model/CarogDetails_model.dart';
import 'package:Auras/model/Recommendation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:open_file/open_file.dart';

Future<void> generateSeafasteningPdfWithHeader({
  required String jobNumber,
  required String certificateNumber,
  required String projectTitle,
  required String client,
  required String CargoType,
  required String transportunit,
  required List<Recommendation> recommendations,

  required String cargo,
  required String fromPort,
  required String toPort,
  required String HeaderImagePath,
  required String Certificatetitle,
  required bool isCargoDetailsNA,
  required bool includeAnnexure2,
  required String issuedBy,
  Uint8List? stampBytes,
  List<CargoDetail>? cargoDetails, // <<< NEW
  List<Recommendation>? recommendation,
  Uint8List? clientBytes,
  Uint8List? signatureBytes,
  required String issuedDate,
  required int certificateId,
}) async {
  // Use cargoDetails if provided, else fetch from DB:
  List<CargoDetail> finalCargoDetails = [];
  if (certificateId != 0) {
    finalCargoDetails = await DatabaseHelper().getCargoDetails(certificateId);
  } else if (cargoDetails != null) {
    finalCargoDetails = cargoDetails;
  }

  List<Recommendation> finalRecommendations = [];
  if (certificateId != 0) {
    finalRecommendations = await DatabaseHelper()
        .getSeafasteningRecommendations(certificateId);
  } else if (recommendations != null) {
    finalRecommendations = recommendations;
  }

  final document = sf.PdfDocument();
  final page = document.pages.add();
  final graphics = page.graphics;

  final boldFont = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    10,
    style: sf.PdfFontStyle.bold,
  );
  final normalFont = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 13);
  final titleFont = sf.PdfStandardFont(
    sf.PdfFontFamily.timesRoman,
    11,
    style: sf.PdfFontStyle.bold,
  );

  final double pageWidth = page.getClientSize().width;
  final double pageHeight = page.getClientSize().height;
  const double margin = 15;
  final double contentWidth = pageWidth - 2 * margin;
  double y = margin;

  // Draw outer border
  graphics.drawRectangle(
    pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
    bounds: Rect.fromLTWH(
      margin - 10,
      margin - 10,
      contentWidth + 20,
      pageHeight - 2 * margin + 20,
    ),
  );

  List<Recommendation> _recommendations = [];

  // Future<List<String>> fetchRecommendationsFromDB(int certificateId) async {
  //   final db = await DatabaseHelper().database;
  //   final result = await db.query(
  //     'default_recommendations',
  //     where: 'certificateId = ?',
  //     whereArgs: [certificateId],
  //   );
  //   return result.map((e) => e['recommendationText'] as String).toList();
  // }

  try {
    final imageData = await rootBundle.load(HeaderImagePath);
    final headerImage = sf.PdfBitmap(imageData.buffer.asUint8List());
    graphics.drawImage(headerImage, Rect.fromLTWH(margin - 6, y - 8, 500, 45));
    y += 40;
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

  graphics.drawString(
    'CERTIFICATE OF APPROVAL - SEA FASTENING & LASHING',
    titleFont,
    bounds: Rect.fromLTWH(margin, y, contentWidth, 20),
    format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
  );
  y += 25;

  final grid = sf.PdfGrid();
  grid.columns.add(count: 2);
  final details = {
    'PROJECT': projectTitle,
    'CLIENT': client,
    'TRANSPORTUNIT': transportunit,
    'CARGO': cargo,
    'FROM': fromPort,
    'TO': toPort,
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

  y += 10;

  const double sidePadding = 16; // Adjust side padding for narrower paragraph
  final double paragraphX = margin + sidePadding;
  final double paragraphWidth = contentWidth - 2 * sidePadding;
  // Make a smaller font for paragraph
  final smallFont = sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 10);

  // Then use it in the paragraph
  final paragraphText = sf.PdfTextElement(
    text:
        "This is to certify that this office, acting on behalf of $client, has reviewed the procedures and witnessed the $CargoType of Project cargo/equipment/machinery on the transport unit in preparation of the proposed voyage. Cargo details are annexed to this certificate. REFER ANNEXURE-2.\n\n"
        "The $CargoType are considered suitable for the proposed voyage subject to satisfactory compliance with the attached recommendations(Annexure-1).\n\n"
        "This certificate is issued subject to $Certificatetitle Terms and Conditions of Business, current at the time of issue without prejudice to any insurance interests or to any or all parties concerned.Any alterations in the surveyed items or deviations from the agreed procedures after issue of this certificate may render the certificate invalid unless specifically approved by this office.\n\n",

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
    Certificatetitle,
    boldFont,
    bounds: Rect.fromLTWH(margin + indent, y, contentWidth - indent * 2, 20),
  );
  y += 25;

  // --- Responsibility Table ---
  final page1Table = buildResponsibilityTable(
    surveyedBy: issuedBy,
    fromPort: fromPort,
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
    bounds: Rect.fromLTWH(margin + 25, pageHeight - 85, contentWidth, 0),
  );

  // ANNEXURE-1 RECOMMENDATIONS
  if (!includeAnnexure2 == true) {
    final recTexts = finalRecommendations
        .map((r) => r.recommendationText ?? '')
        .where((text) => text.trim().isNotEmpty)
        .toList();

    if (recTexts.isNotEmpty) {
      final annexurePage = document.pages.add();
      final annexureGraphics = annexurePage.graphics;
      final annexureWidth = annexurePage.getClientSize().width;
      final annexureHeight = annexurePage.getClientSize().height;

      const double margin = 15;
      double y = margin;

      // ➤ Draw border
      annexureGraphics.drawRectangle(
        pen: sf.PdfPen(sf.PdfColor(0, 0, 0), width: 1.3),
        bounds: Rect.fromLTWH(
          margin - 10,
          margin - 10,
          annexureWidth - (margin - 10) * 2,
          annexureHeight - (margin - 10) * 2,
        ),
      );

      // ➤ Title
      annexureGraphics.drawString(
        "ANNEXURE-1 RECOMMENDATIONS TO CERTIFICATE OF APPROVAL –",
        boldFont,
        bounds: Rect.fromLTWH(0, y + 15, annexureWidth, 20),
        format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
      );

      // ➤ Certificate Number
      annexureGraphics.drawString(
        "$jobNumber/$certificateNumber",
        boldFont,
        bounds: Rect.fromLTWH(0, y + 35, annexureWidth, 20),
        format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
      );

      // ➤ Subtitle
      annexureGraphics.drawString(
        "RECOMMENDATIONS",
        boldFont,
        bounds: Rect.fromLTWH(0, y + 60, annexureWidth, 20),
        format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
      );

      // ➤ Recommendation Table
      final recommendationTable = sf.PdfGrid();
      recommendationTable.columns.add(count: 2);
      recommendationTable.columns[0].width = 40;

      final headerRow = recommendationTable.headers.add(1)[0];
      headerRow.cells[0].value = "Sl. No.";
      headerRow.cells[1].value =
          "Recommendations to be completed prior departure";

      for (int i = 0; i < 2; i++) {
        headerRow.cells[i].style
          ..font = sf.PdfStandardFont(
            sf.PdfFontFamily.timesRoman,
            10,
            style: sf.PdfFontStyle.bold,
          )
          ..backgroundBrush = sf.PdfBrushes.lightGray
          ..stringFormat = sf.PdfStringFormat(
            alignment: sf.PdfTextAlignment.center,
          );
      }

      // ➤ Rows
      for (int i = 0; i < recTexts.length; i++) {
        final row = recommendationTable.rows.add();
        row.cells[0].value = "${i + 1}";
        row.cells[1].value = recTexts[i];
      }

      recommendationTable.style = sf.PdfGridStyle(
        font: sf.PdfStandardFont(sf.PdfFontFamily.timesRoman, 9),
        cellPadding: sf.PdfPaddings(left: 2, top: 2, right: 2, bottom: 2),
      );

      final recTableResult = recommendationTable.draw(
        page: annexurePage,
        bounds: Rect.fromLTWH(
          margin + 10,
          y + 90,
          annexureWidth - 2 * margin - 10,
          0,
        ),
      );

      final double yAfterTable = recTableResult!.bounds.bottom + 30;
      final double pageHeight = annexureHeight;
      const double stampAndTextHeight = 100;
      const double responsibilityTableHeight = 110;
      final double requiredHeight =
          stampAndTextHeight + responsibilityTableHeight + 30;

      final bool needsNewPage = yAfterTable + requiredHeight > pageHeight;

      final targetPage = needsNewPage ? document.pages.add() : annexurePage;
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
        Certificatetitle,
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
        surveyedBy: issuedBy,
        fromPort: fromPort,
        issuedDate: issuedDate,
        signatureBytes: signatureBytes,
        boldFont: boldFont,
      );

      final double tableY = baseY + stampAndTextHeight;
      responsibilityTable.draw(
        page: targetPage,
        bounds: Rect.fromLTWH(
          margin + 45,
          tableY,
          targetPageSize.width - (margin + 25) * 2,
          0,
        ),
      );
    }
  }

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
      Certificatetitle,
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
      surveyedBy: issuedBy,
      fromPort: fromPort,
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
      "This is certified that $Certificatetitle carried out Certificate of Approval Seafastening & Lashing SURVEY on project $projectTitle at $fromPort, as per the requirements of $client.";
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
    "Duration of Job:From _______________To_____________",
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
    "Job Description:Sea fastening and lashing approval of CARGO loaded on board $transportunit from $fromPort to $toPort.",
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
    "Name: $issuedBy",
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
    bounds: Rect.fromLTWH(workMargin + xShift, yOffset, 200, 20),
  );

  // // ➤ 🧾 STAMP Image logic (middle right beside Aries block)
  // if (stampBytes != null && stampBytes.isNotEmpty) {
  //   final stampImage = sf.PdfBitmap(stampBytes);
  //   // aligned vertically with Aries section, and shifted right
  //   final double stampX = workPageWidth / 2 - 100;
  //   final double stampY = yOffset - 140;
  //   workDoneGraphics.drawImage(
  //     stampImage,
  //     Rect.fromLTWH(stampX, stampY, 100, 60),
  //   );
  // }

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
    text: "Company: $client",
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
    rightY += 60;
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
    ["CLIENT", "$client"],
    ["VESSEL/PROJECT NAME", '$projectTitle'],
    ["LOCATION", "$fromPort"],
    ["NAME OF PERSON", "$issuedBy"],
    ["TIME SHEET NO", "01"],
    ["JOB NO", "$jobNumber"],
    [
      "TYPE OF JOB",
      "Marine warranty/Marine Assuarance Survey - Seafastening Survey",
    ],
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
    "Name: $issuedBy",
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

  // // ➤ 🧾 STAMP Image logic (middle right beside Aries block)
  // if (stampBytes != null && stampBytes.isNotEmpty) {
  //   final stampImage = sf.PdfBitmap(stampBytes);
  //   // aligned vertically with Aries section, and shifted right
  //   final double stampX = workPageWidth / 2 - 100;
  //   final double stampY = yOffset - 60;
  //   workDoneGraphics1.drawImage(
  //     stampImage,
  //     Rect.fromLTWH(stampX, stampY, 100, 60),
  //   );
  // }

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
    "Company: $projectTitle",
    normalFont1,
    bounds: Rect.fromLTWH(rightColX, rightY1, 200, 20),
  );
  rightY1 += 20;
  if (clientBytes != null && clientBytes.isNotEmpty) {
    final clientSignature = sf.PdfBitmap(clientBytes);
    workDoneGraphics1.drawImage(
      clientSignature,
      Rect.fromLTWH(rightColX, rightY1, 120, 40), // Bigger and visible
    );
    rightY1 += 50; // Adjust spacing
  } else {
    workDoneGraphics1.drawString(
      "Signature:",
      normalFont1,
      bounds: Rect.fromLTWH(rightColX, rightY1, 200, 20),
    );
    rightY1 += 20;
  }

  rightY1 += 5;
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

  for (int i = 0; i < document.pages.count; i++) {
    // 👇 Skip Work Done or Timesheet pages
    if (i == workDonePageIndex || i == timesheetPageIndex) continue;

    final page = document.pages[i];
    final graphics = page.graphics;
    final pageSize = page.getClientSize();

    graphics.drawString(
      'AM/DS -TC-01_R0',
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
  final file = File('${dir.path}/seafastening.pdf');
  await file.writeAsBytes(bytes);
  await OpenFile.open(file.path);
}

sf.PdfGrid buildResponsibilityTable({
  required String surveyedBy,
  required String fromPort,
  required String issuedDate,
  Uint8List? signatureBytes,
  required sf.PdfFont boldFont,
}) {
  final table = sf.PdfGrid();
  table.columns.add(count: 5);

  final header = table.headers.add(1)[0];
  const headers = ['Responsibility', 'Name', 'Location', 'Signature', 'Date'];
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
  row.cells[2].value = fromPort;
  row.cells[4].value = issuedDate;

  if (signatureBytes != null) {
    final sig = sf.PdfBitmap(signatureBytes);
    row.cells[3].value = '';
    row.cells[3].style.backgroundImage = sig;
  }

  table.style = sf.PdfGridStyle(
    cellPadding: sf.PdfPaddings(left: 4, top: 4, right: 4, bottom: 4),
  );
  return table;
}
