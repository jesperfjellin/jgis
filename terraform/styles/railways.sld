<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>railways</Name>
    <UserStyle>
      <Title>Railways</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>rail</Name>
          <MaxScaleDenominator>1000000</MaxScaleDenominator>
          <LineSymbolizer><Stroke><CssParameter name="stroke">#707070</CssParameter><CssParameter name="stroke-width">1.2</CssParameter><CssParameter name="stroke-linecap">round</CssParameter><CssParameter name="stroke-dasharray">6 3</CssParameter></Stroke></LineSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
