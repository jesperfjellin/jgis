<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>waterways</Name>
    <UserStyle>
      <Title>Waterways</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>rivers</Name>
          <ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>river</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter>
          <MaxScaleDenominator>2000000</MaxScaleDenominator>
          <LineSymbolizer><Stroke><CssParameter name="stroke">#aad3df</CssParameter><CssParameter name="stroke-width">1.5</CssParameter><CssParameter name="stroke-linecap">round</CssParameter></Stroke></LineSymbolizer>
        </Rule>
        <Rule>
          <Name>small</Name>
          <ogc:Filter><ogc:Not><ogc:PropertyIsEqualTo><ogc:PropertyName>class</ogc:PropertyName><ogc:Literal>river</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Not></ogc:Filter>
          <MaxScaleDenominator>100000</MaxScaleDenominator>
          <LineSymbolizer><Stroke><CssParameter name="stroke">#aad3df</CssParameter><CssParameter name="stroke-width">0.8</CssParameter><CssParameter name="stroke-linecap">round</CssParameter></Stroke></LineSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
