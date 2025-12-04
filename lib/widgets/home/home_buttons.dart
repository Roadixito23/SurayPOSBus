import 'package:flutter/material.dart';

/// Widget para botones configurables en la pantalla Home
class HomeButtons {
  /// Construye un botón configurable con ícono y texto
  static Widget buildConfigurableButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Function() onPressed,
    required bool showIcons,
    required double textSizeMultiplier,
    required Map<String, IconData> buttonIcons,
    bool isDisabled = false,
    Color textColor = Colors.white,
  }) {
    double screenWidth = MediaQuery.of(context).size.width;
    double buttonWidth = screenWidth - (MediaQuery.of(context).size.width * 0.1);
    double textSize = buttonWidth * 0.056;

    IconData buttonIcon = _getButtonIcon(text, icon, buttonIcons);

    return Container(
      constraints: BoxConstraints(
        minHeight: 60,
      ),
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: borderColor,
            width: 3,
          ),
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: showIcons
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    buttonIcon,
                    size: textSize * textSizeMultiplier * 0.9,
                  ),
                  SizedBox(width: 0),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: textSize * textSizeMultiplier,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: textSize * textSizeMultiplier,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
      ),
    );
  }

  /// Obtiene el ícono del botón desde el mapa de configuración o usa el ícono por defecto
  static IconData _getButtonIcon(
    String buttonName,
    IconData defaultIcon,
    Map<String, IconData> buttonIcons,
  ) {
    return buttonIcons[buttonName] ?? defaultIcon;
  }
}
