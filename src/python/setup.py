from setuptools import setup, find_packages

setup(
    name="hft-exchange-simulator",
    version="0.1.0",
    description="Simulator for HFT Exchange FPGA testing",
    author="Your Name",
    packages=find_packages(),
    install_requires=[
        "pyserial>=3.5",
    ],
    python_requires=">=3.6",
)