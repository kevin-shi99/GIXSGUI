import numpy as np

class GixsDataCorrections:
    """
    Python implementation of MATLAB gixsdata correction functions using NumPy.
    These functions are extracted and converted from the gixsdata.m file.
    """
    
    def solidangle_correction(self, obj):
        """
        Performs solid angle correction to RawData, regardless the Mask.
        Flat field and efficiency correction, if defined, are also applied.
        
        Parameters:
        -----------
        obj : object
            Object containing the following attributes:
            - Beam0: tuple/list of 2 elements
            - PixelSize: tuple/list of 2 elements
            - SDD: scalar (sample to detector distance)
            - XEnergy: scalar
            - QMap: 2D array
            - RawData: 2D array
            - ImDim: tuple/list of 2 elements (image dimensions)
            - FlatField: 2D array (optional)
            - CustomCorrection: 2D array (optional)
            - EfficiencyCorrection: dict/list (optional)
            - PolarizationMode: int (optional)
            - LorentzFactorType: int (optional)
        
        Returns:
        --------
        SolidAngleCorrectedData : numpy.ndarray
            Solid angle corrected data
        """
        # Check for required parameters
        nan_list = [obj.Beam0[0], obj.Beam0[1], obj.PixelSize[0], obj.PixelSize[1], 
                    obj.SDD, obj.XEnergy]
        if np.any(np.isnan(nan_list)) or obj.QMap is None or len(obj.QMap) == 0:
            return None
        
        if obj.RawData is None or len(obj.RawData) == 0:
            return None
        
        # Create coordinate grids
        x, y = np.meshgrid(np.arange(1, obj.ImDim[0] + 1), 
                          np.arange(1, obj.ImDim[1] + 1))
        
        # Calculate complex radius
        r_complex = (obj.PixelSize[0] * (x - obj.Beam0[0]) + 
                    1j * obj.PixelSize[1] * (obj.Beam0[1] - y))
        r = np.abs(r_complex)
        R = np.sqrt(r**2 + obj.SDD**2)  # pixel to sample distance
        theta = np.arctan(r / obj.SDD)  # exit angle map
        
        # Calculate solid angle
        dOmega = obj.PixelSize[0] * obj.PixelSize[1] * np.cos(theta) / R**2
        dOmega = dOmega / np.max(dOmega)  # normalize solid angle
        
        # Apply solid angle correction
        SolidAngleCorrectedData = obj.RawData.astype(np.float32) / dOmega
        
        # Apply flat field correction if available
        if hasattr(obj, 'FlatField') and obj.FlatField is not None:
            if obj.FlatField.shape == SolidAngleCorrectedData.shape:
                SolidAngleCorrectedData = SolidAngleCorrectedData * obj.FlatField
        
        # Apply custom correction if available
        if hasattr(obj, 'CustomCorrection') and obj.CustomCorrection is not None:
            if obj.CustomCorrection.shape == SolidAngleCorrectedData.shape:
                SolidAngleCorrectedData = SolidAngleCorrectedData * obj.CustomCorrection
        
        # Apply efficiency correction if available
        if hasattr(obj, 'EfficiencyCorrection'):
            effcdata = self.efficiency_correction(obj)
            if effcdata is not None and effcdata.shape == SolidAngleCorrectedData.shape:
                SolidAngleCorrectedData = SolidAngleCorrectedData * effcdata
        
        # Apply polarization correction if available
        if hasattr(obj, 'PolarizationMode'):
            polardata = self.polarization_correction(obj)
            if polardata is not None and polardata.shape == SolidAngleCorrectedData.shape:
                SolidAngleCorrectedData = SolidAngleCorrectedData / polardata
        
        # Apply Lorentz correction if available
        if hasattr(obj, 'LorentzFactorType'):
            CL = self.lorentzfactor(obj)
            if CL is not None:
                SolidAngleCorrectedData = SolidAngleCorrectedData / CL
        
        return SolidAngleCorrectedData
    
    def efficiency_correction(self, obj):
        """
        Calculates efficiency correction array from property EfficiencyCorrection.
        
        Parameters:
        -----------
        obj : object
            Object containing:
            - XWavelength: scalar (X-ray wavelength in Angstroms)
            - QMap: 2D array
            - EfficiencyCorrection: 2x3 list/array with:
              [0][0]: path medium chemical formula (string)
              [0][1]: path medium mass density (g/cm³)
              [0][2]: path medium length (mm)
              [1][0]: detector sensor chemical formula (string)
              [1][1]: detector sensor mass density (g/cm³)
              [1][2]: detector sensor depth (mm)
        
        Returns:
        --------
        c : numpy.ndarray
            Correction array of the same dimension as the image data
        """
        # Calculate diffraction theta
        k = 2 * np.pi / obj.XWavelength
        theta = 2 * np.arcsin(obj.QMap / (2 * k))
        
        # Get efficiency correction parameters
        objeffc = obj.EfficiencyCorrection
        
        # First correction coefficient for path absorption
        try:
            # Note: refrac function would need to be implemented separately
            # For now, we'll use a simplified calculation
            # In real implementation, you'd need the refrac function from xrayrefraction
            
            # Simplified attenuation calculation for path medium
            # This is a placeholder - actual implementation would use refrac function
            att1 = 10.0  # mm (example value, should be calculated from refrac)
            c1 = 1.0 / np.exp(-objeffc[0][2] / np.cos(theta) / att1)
        except:
            c1 = np.ones_like(obj.QMap)
        
        # Second correction coefficient for chip attenuation
        try:
            # Simplified attenuation calculation for detector sensor
            # This is a placeholder - actual implementation would use refrac function
            att2 = 10.0  # mm (example value, should be calculated from refrac)
            c2 = 1.0 / (1 - np.exp(-objeffc[1][2] / np.cos(theta) / att2))
        except:
            c2 = np.ones_like(obj.QMap)
        
        c = c1 * c2
        c = c.astype(np.float32) / np.max(c)
        
        return c
    
    def polarization_correction(self, obj):
        """
        Calculates polarization correction array using polarization parameters.
        
        Parameters:
        -----------
        obj : object
            Object containing:
            - XWavelength: scalar
            - ImDim: tuple/list of 2 elements
            - Beam0: tuple/list of 2 elements
            - PixelSize: tuple/list of 2 elements
            - SDD: scalar
            - PolarizationMode: int (1-4)
            - HorizontalPolarizationFraction: float (0-1)
        
        Returns:
        --------
        c : numpy.ndarray
            Correction array of the same dimension as the image data
        """
        k = 2 * np.pi / obj.XWavelength
        
        # Create coordinate grids
        x, y = np.meshgrid(np.arange(1, obj.ImDim[0] + 1), 
                          np.arange(1, obj.ImDim[1] + 1))
        
        r_complex = (obj.PixelSize[0] * (x - obj.Beam0[0]) + 
                    1j * obj.PixelSize[1] * (obj.Beam0[1] - y))
        
        gamma = np.arctan(np.real(r_complex) / obj.SDD)
        delta = np.arctan(np.imag(r_complex) / np.sqrt(obj.SDD**2 + np.real(r_complex)**2))
        
        # Calculate polarization factors
        uc = (1 + np.cos(delta)**2 * np.cos(gamma)**2) / 2  # for unpolarized
        hpf = obj.HorizontalPolarizationFraction
        ch = 1 - np.cos(delta)**2 * np.sin(gamma)**2  # for fully horizontal
        cv = np.cos(delta)**2  # for fully vertical
        
        # Apply polarization mode
        if obj.PolarizationMode == 1:
            c = np.ones((obj.ImDim[1], obj.ImDim[0]))
        elif obj.PolarizationMode == 2:
            c = hpf * ch + (1 - hpf) * cv
        elif obj.PolarizationMode == 3:
            c = hpf * cv + (1 - hpf) * ch
        elif obj.PolarizationMode == 4:
            c = uc
        else:
            c = np.ones((obj.ImDim[1], obj.ImDim[0]))
        
        return c.astype(np.float32)
    
    def lorentzfactor(self, obj):
        """
        Calculate Lorentz factor with given type.
        
        Parameters:
        -----------
        obj : object
            Object containing:
            - LorentzFactorType: int (1-4)
            - SolidAngleCorrectedData: 2D array
            - IncidentAngle: scalar (for types 2 and 3)
            - AlphafMap: 2D array (for types 2 and 3)
            - TwoThetaMap: 2D array (for types 2 and 3)
            - QMap: 2D array (for type 4)
            - XWavelength: scalar (for type 4)
        
        Returns:
        --------
        c_lf : numpy.ndarray
            Lorentz factor correction array
        """
        if obj.LorentzFactorType == 1:  # no correction
            c_lf = np.ones_like(obj.SolidAngleCorrectedData)
        
        elif obj.LorentzFactorType == 2:  # in-plane random 3D
            c_lf = (np.cos(np.radians(obj.IncidentAngle)) * 
                   np.cos(np.radians(obj.AlphafMap)) * 
                   np.sin(np.radians(obj.TwoThetaMap)))
        
        elif obj.LorentzFactorType == 3:  # in-plane random 2D
            c_lf = np.sin(np.radians(obj.TwoThetaMap))
        
        elif obj.LorentzFactorType == 4:  # completely random
            k = 2 * np.pi / obj.XWavelength
            transmission_th = np.arcsin(obj.QMap / (2 * k))
            c_lf = 4 * (np.sin(transmission_th))**2 * np.cos(transmission_th)
        
        else:
            c_lf = np.ones_like(obj.SolidAngleCorrectedData)
        
        # Inverse to get Lorentz factor
        c_lf = np.abs(c_lf)
        c_lf = np.max(c_lf) / c_lf
        
        return c_lf


# Example usage:
if __name__ == "__main__":
    # Create a simple object to demonstrate usage
    class SimpleObj:
        def __init__(self):
            # Example parameters
            self.Beam0 = [100, 100]
            self.PixelSize = [0.172, 0.172]
            self.SDD = 200.0  # mm
            self.XEnergy = 10.86  # keV
            self.XWavelength = 12.3984171668278 / self.XEnergy  # Angstroms
            self.ImDim = [200, 200]
            self.PolarizationMode = 2
            self.HorizontalPolarizationFraction = 1.0
            self.LorentzFactorType = 1
            
            # Example data
            self.RawData = np.random.rand(200, 200) * 1000
            self.QMap = np.random.rand(200, 200) * 5
            self.SolidAngleCorrectedData = np.random.rand(200, 200) * 1000
            
            # Example efficiency correction parameters
            self.EfficiencyCorrection = [
                ['N78O21Ar', 1.1839e-3, 0],      # air
                ['Si', 2.33, 0.32]                # silicon detector
            ]
    
    # Create correction object and test object
    corrections = GixsDataCorrections()
    test_obj = SimpleObj()
    
    # Test the functions
    print("Testing correction functions...")
    
    # Test polarization correction
    pol_corr = corrections.polarization_correction(test_obj)
    print(f"Polarization correction shape: {pol_corr.shape}")
    print(f"Polarization correction range: [{np.min(pol_corr):.4f}, {np.max(pol_corr):.4f}]")
    
    # Test efficiency correction
    eff_corr = corrections.efficiency_correction(test_obj)
    print(f"\nEfficiency correction shape: {eff_corr.shape}")
    print(f"Efficiency correction range: [{np.min(eff_corr):.4f}, {np.max(eff_corr):.4f}]")
    
    # Test Lorentz factor
    lorentz = corrections.lorentzfactor(test_obj)
    print(f"\nLorentz factor shape: {lorentz.shape}")
    print(f"Lorentz factor range: [{np.min(lorentz):.4f}, {np.max(lorentz):.4f}]")
    
    # Test solid angle correction
    solid_angle_corr = corrections.solidangle_correction(test_obj)
    if solid_angle_corr is not None:
        print(f"\nSolid angle corrected data shape: {solid_angle_corr.shape}")
        print(f"Solid angle corrected data range: [{np.min(solid_angle_corr):.4f}, {np.max(solid_angle_corr):.4f}]")
